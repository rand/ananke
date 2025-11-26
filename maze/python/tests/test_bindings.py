"""
Basic tests for Ananke Python bindings (Phase 7a)

Tests the PyO3 bindings without requiring a live Modal endpoint.
"""

import pytest
import sys
import os


def test_import_ananke():
    """Test that the ananke module can be imported"""
    try:
        import ananke
        assert ananke is not None
    except ImportError as e:
        pytest.skip(f"Ananke module not built yet: {e}")


def test_constraint_ir_creation():
    """Test PyConstraintIR can be created"""
    try:
        from ananke import PyConstraintIR

        constraint = PyConstraintIR(
            name="test_constraint",
            json_schema='{"type": "string"}',
            grammar=None,
            regex_patterns=[]
        )

        assert constraint.name == "test_constraint"
        assert constraint.json_schema == '{"type": "string"}'
        assert constraint.grammar is None
        assert constraint.regex_patterns == []
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_generation_context_creation():
    """Test PyGenerationContext can be created"""
    try:
        from ananke import PyGenerationContext

        context = PyGenerationContext(
            current_file="test.py",
            language="python",
            project_root="/tmp/test"
        )

        assert context.current_file == "test.py"
        assert context.language == "python"
        assert context.project_root == "/tmp/test"
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_generation_request_creation():
    """Test PyGenerationRequest can be created"""
    try:
        from ananke import PyGenerationRequest, PyConstraintIR, PyGenerationContext

        constraint = PyConstraintIR(
            name="security_constraint",
            json_schema=None,
            grammar=None,
            regex_patterns=[]
        )

        context = PyGenerationContext(
            current_file="app.py",
            language="python",
            project_root="/app"
        )

        request = PyGenerationRequest(
            prompt="Generate a secure API handler",
            constraints_ir=[constraint],
            max_tokens=100,
            temperature=0.7,
            context=context
        )

        assert request.prompt == "Generate a secure API handler"
        assert len(request.constraints_ir) == 1
        assert request.max_tokens == 100
        # f32 precision: check within tolerance
        assert abs(request.temperature - 0.7) < 0.01
        assert request.context is not None
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_modal_config_creation():
    """Test PyModalConfig can be created"""
    try:
        from ananke import PyModalConfig

        config = PyModalConfig(
            endpoint_url="https://test-endpoint.modal.run",
            model="meta-llama/Llama-3.1-8B-Instruct",
            api_key="test_key",
            timeout_secs=300,
            max_retries=3
        )

        # PyModalConfig has a __repr__ method we can test
        repr_str = repr(config)
        assert "test-endpoint.modal.run" in repr_str
        assert "meta-llama" in repr_str
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_ananke_initialization():
    """Test Ananke class can be initialized"""
    try:
        from ananke import Ananke

        # Initialize with explicit parameters
        ananke = Ananke(
            modal_endpoint="https://test.modal.run",
            modal_api_key="test_key",
            model="meta-llama/Llama-3.1-8B-Instruct",
            timeout_secs=300,
            enable_cache=True,
            cache_size=1000
        )

        assert ananke is not None

        # Test __repr__
        repr_str = repr(ananke)
        assert "Ananke" in repr_str
    except ImportError:
        pytest.skip("Ananke module not built yet")


@pytest.mark.asyncio
async def test_ananke_generate_signature():
    """Test that generate() method exists and has correct signature"""
    try:
        from ananke import Ananke, PyGenerationRequest

        ananke = Ananke(
            modal_endpoint="https://test.modal.run",
            modal_api_key="test_key"
        )

        # Verify the generate method exists
        assert hasattr(ananke, 'generate')
        assert callable(getattr(ananke, 'generate'))

        # Note: We don't actually call generate() without a real endpoint
        # This test just verifies the method signature exists
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_constraint_ir_repr():
    """Test PyConstraintIR __repr__ method"""
    try:
        from ananke import PyConstraintIR

        constraint = PyConstraintIR(
            name="test_repr",
            json_schema=None,
            grammar=None,
            regex_patterns=[]
        )

        repr_str = repr(constraint)
        assert "PyConstraintIR" in repr_str
        assert "test_repr" in repr_str
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_generation_context_repr():
    """Test PyGenerationContext __repr__ method"""
    try:
        from ananke import PyGenerationContext

        context = PyGenerationContext(
            current_file="test.py",
            language="python",
            project_root=None
        )

        repr_str = repr(context)
        assert "PyGenerationContext" in repr_str
        assert "python" in repr_str
    except ImportError:
        pytest.skip("Ananke module not built yet")


def test_all_classes_exported():
    """Test that all expected classes are exported from the module"""
    try:
        import ananke

        expected_classes = [
            'Ananke',
            'PyModalConfig',
            'PyConstraintIR',
            'PyGenerationRequest',
            'PyGenerationResponse',
            'PyGenerationContext',
            'PyProvenance',
            'PyValidationResult',
            'PyGenerationMetadata',
        ]

        for class_name in expected_classes:
            assert hasattr(ananke, class_name), f"Missing class: {class_name}"
    except ImportError:
        pytest.skip("Ananke module not built yet")


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v"])
