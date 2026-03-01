//! Type Inhabitation Module
//!
//! This module provides type inhabitation analysis for constrained code generation.
//! It determines which tokens can lead to expressions of a target type.

pub const type_system = @import("type_system.zig");
pub const parser = @import("parser.zig");
pub const inhabitation = @import("inhabitation.zig");
pub const mask_generator = @import("mask_generator.zig");

// Re-export commonly used types
pub const Type = type_system.Type;
pub const TypeArena = type_system.TypeArena;
pub const Language = type_system.Language;
pub const PrimitiveKind = type_system.PrimitiveKind;

pub const TypeParser = parser.TypeParser;
pub const ParseError = parser.ParseError;

pub const InhabitationGraph = inhabitation.InhabitationGraph;
pub const Edge = inhabitation.Edge;
pub const EdgeKind = inhabitation.EdgeKind;
pub const Binding = inhabitation.Binding;

pub const MaskGenerator = mask_generator.MaskGenerator;
pub const TokenMaskData = mask_generator.TokenMaskData;
pub const TypeInhabitationState = mask_generator.TypeInhabitationState;
pub const TypeInhabitationBuilder = mask_generator.TypeInhabitationBuilder;
pub const TokenizerInterface = mask_generator.TokenizerInterface;
pub const HoleBinding = mask_generator.HoleBinding;

test {
    _ = type_system;
    _ = parser;
    _ = inhabitation;
    _ = mask_generator;
}
