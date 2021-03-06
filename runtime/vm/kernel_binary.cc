// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
#if !defined(DART_PRECOMPILED_RUNTIME)

#include "vm/kernel_binary.h"
#include "platform/globals.h"
#include "vm/compiler/frontend/kernel_to_il.h"
#include "vm/dart_api_impl.h"
#include "vm/flags.h"
#include "vm/growable_array.h"
#include "vm/kernel.h"
#include "vm/os.h"

namespace dart {

namespace kernel {

const char* Reader::TagName(Tag tag) {
  switch (tag) {
#define CASE(Name, value)                                                      \
  case k##Name:                                                                \
    return #Name;
    KERNEL_TAG_LIST(CASE)
#undef CASE
    default:
      break;
  }
  return "Unknown";
}

const char* kKernelInvalidFilesize =
    "File size is too small to be a valid kernel file";
const char* kKernelInvalidMagicIdentifier = "Invalid magic identifier";
const char* kKernelInvalidBinaryFormatVersion =
    "Invalid kernel binary format version";
const char* kKernelInvalidSizeIndicated =
    "Invalid kernel binary: Indicated size is invalid";

Program* Program::ReadFrom(Reader* reader, const char** error) {
  if (reader->size() < 60) {
    // A kernel file currently contains at least the following:
    //   * Magic number (32)
    //   * Kernel version (32)
    //   * List of problems (8)
    //   * Length of source map (32)
    //   * Length of canonical name table (8)
    //   * Metadata length (32)
    //   * Length of string table (8)
    //   * Length of constant table (8)
    //   * Component index (10 * 32)
    //
    // so is at least 60 bytes.
    // (Technically it will also contain an empty entry in both source map and
    // string table, taking up another 8 bytes.)
    if (error != nullptr) {
      *error = kKernelInvalidFilesize;
    }
    return nullptr;
  }

  uint32_t magic = reader->ReadUInt32();
  if (magic != kMagicProgramFile) {
    if (error != nullptr) {
      *error = kKernelInvalidMagicIdentifier;
    }
    return nullptr;
  }

  uint32_t formatVersion = reader->ReadUInt32();
  if ((formatVersion < kMinSupportedKernelFormatVersion) ||
      (formatVersion > kMaxSupportedKernelFormatVersion)) {
    if (error != nullptr) {
      *error = kKernelInvalidBinaryFormatVersion;
    }
    return nullptr;
  }

  Program* program = new Program();
  program->binary_version_ = formatVersion;
  program->kernel_data_ =
      &TypedDataBase::ZoneHandle(reader->typed_data()->raw());

  // Dill files can be concatenated (e.g. cat a.dill b.dill > c.dill). Find out
  // if this dill contains more than one program.
  int subprogram_count = 0;
  reader->set_offset(reader->size() - 4);
  while (reader->offset() > 0) {
    intptr_t size = reader->ReadUInt32();
    intptr_t start = reader->offset() - size;
    if (start < 0) {
      if (error != nullptr) {
        *error = kKernelInvalidSizeIndicated;
      }
      delete program;
      return nullptr;
    }
    ++subprogram_count;
    if (subprogram_count > 1) break;
    reader->set_offset(start - 4);
  }
  program->single_program_ = subprogram_count == 1;

  // Read backwards at the end.
  program->library_count_ = reader->ReadFromIndexNoReset(
      reader->size_, LibraryCountFieldCountFromEnd, 1, 0);
  program->source_table_offset_ = reader->ReadFromIndexNoReset(
      reader->size_,
      LibraryCountFieldCountFromEnd + 1 + program->library_count_ + 1 +
          SourceTableFieldCountFromFirstLibraryOffset,
      1, 0);
  program->name_table_offset_ = reader->ReadUInt32();
  program->metadata_payloads_offset_ = reader->ReadUInt32();
  program->metadata_mappings_offset_ = reader->ReadUInt32();
  program->string_table_offset_ = reader->ReadUInt32();
  program->constant_table_offset_ = reader->ReadUInt32();

  program->main_method_reference_ = NameIndex(reader->ReadUInt32() - 1);

  return program;
}

Program* Program::ReadFromFile(const char* script_uri,
                               const char** error /* = nullptr */) {
  Thread* thread = Thread::Current();
  if (script_uri == NULL) {
    return NULL;
  }

  const String& uri = String::Handle(String::New(script_uri));
  const Object& ret = Object::Handle(thread->isolate()->CallTagHandler(
      Dart_kKernelTag, Object::null_object(), uri));
  if (ret.IsError()) {
    Api::Scope api_scope(thread);
    Dart_Handle retval = Api::NewHandle(thread, ret.raw());
    TransitionVMToNative transition(thread);
    if (error != nullptr) {
      *error = Dart_GetError(retval);
    }
    return nullptr;
  }

  // NOTE: We require the embedder to supply an external typed data (with a
  // finalizer) so we can simply use it and don't need to make a copy.
  RELEASE_ASSERT(ret.IsExternalTypedData());
  const auto& td = ExternalTypedData::Cast(ret);
  return kernel::Program::ReadFromTypedData(td, error);
}

Program* Program::ReadFromTypedData(const ExternalTypedData& typed_data,
                                    const char** error) {
  kernel::Reader reader(typed_data);
  return kernel::Program::ReadFrom(&reader, error);
}

}  // namespace kernel
}  // namespace dart
#endif  // !defined(DART_PRECOMPILED_RUNTIME)
