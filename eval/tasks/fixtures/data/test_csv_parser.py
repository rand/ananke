"""Tests for CSV parser."""

import pytest
from csv_parser import parse_csv


def test_basic_csv():
    """Test basic CSV parsing."""
    csv_content = """name,age,city
John,30,NYC
Jane,25,LA"""

    result = parse_csv(csv_content)

    assert len(result) == 2
    assert result[0] == {"name": "John", "age": 30, "city": "NYC"}
    assert result[1] == {"name": "Jane", "age": 25, "city": "LA"}


def test_type_conversion_integers():
    """Test automatic conversion of integers."""
    csv_content = """id,count,value
1,100,500"""

    result = parse_csv(csv_content)

    assert result[0]["id"] == 1
    assert isinstance(result[0]["id"], int)
    assert result[0]["count"] == 100
    assert result[0]["value"] == 500


def test_type_conversion_floats():
    """Test automatic conversion of floats."""
    csv_content = """price,rating,score
19.99,4.5,3.14"""

    result = parse_csv(csv_content)

    assert result[0]["price"] == 19.99
    assert isinstance(result[0]["price"], float)
    assert result[0]["rating"] == 4.5
    assert result[0]["score"] == 3.14


def test_mixed_types():
    """Test CSV with mixed data types."""
    csv_content = """name,age,score,active
Alice,28,95.5,true"""

    result = parse_csv(csv_content)

    assert result[0]["name"] == "Alice"
    assert isinstance(result[0]["name"], str)
    assert result[0]["age"] == 28
    assert isinstance(result[0]["age"], int)
    assert result[0]["score"] == 95.5
    assert isinstance(result[0]["score"], float)
    assert result[0]["active"] == "true"


def test_quoted_fields():
    """Test handling of quoted fields with commas."""
    csv_content = """name,address,phone
"Smith, John","123 Main St, Apt 4","555-1234"
"Doe, Jane","456 Oak Ave, Suite 10","555-5678\""""

    result = parse_csv(csv_content)

    assert len(result) == 2
    assert result[0]["name"] == "Smith, John"
    assert result[0]["address"] == "123 Main St, Apt 4"
    assert result[1]["name"] == "Doe, Jane"


def test_whitespace_trimming():
    """Test that whitespace is trimmed from fields."""
    csv_content = """name , age , city
  John  ,  30  ,  NYC
  Jane  ,  25  ,  LA  """

    result = parse_csv(csv_content)

    assert result[0]["name"] == "John"
    assert result[0]["age"] == 30
    assert result[0]["city"] == "NYC"


def test_empty_input():
    """Test handling of empty input."""
    assert parse_csv("") == []
    assert parse_csv("   ") == []
    assert parse_csv("\n\n\n") == []


def test_header_only():
    """Test CSV with only headers."""
    csv_content = """name,age,city"""
    result = parse_csv(csv_content)
    assert result == []


def test_empty_lines_skipped():
    """Test that empty lines are skipped."""
    csv_content = """name,age,city

John,30,NYC

Jane,25,LA

"""

    result = parse_csv(csv_content)

    assert len(result) == 2
    assert result[0]["name"] == "John"
    assert result[1]["name"] == "Jane"


def test_missing_values():
    """Test handling of missing values in rows."""
    csv_content = """name,age,city
John,30
Jane,25,LA,Extra"""

    result = parse_csv(csv_content)

    assert result[0]["name"] == "John"
    assert result[0]["age"] == 30
    assert result[0]["city"] is None  # Missing value


def test_single_row():
    """Test CSV with single data row."""
    csv_content = """name,age
John,30"""

    result = parse_csv(csv_content)

    assert len(result) == 1
    assert result[0] == {"name": "John", "age": 30}


def test_single_column():
    """Test CSV with single column."""
    csv_content = """name
John
Jane
Bob"""

    result = parse_csv(csv_content)

    assert len(result) == 3
    assert result[0] == {"name": "John"}
    assert result[1] == {"name": "Jane"}
    assert result[2] == {"name": "Bob"}


def test_numeric_strings():
    """Test that numeric-looking strings are converted."""
    csv_content = """id,code,value
123,ABC123,456.78"""

    result = parse_csv(csv_content)

    assert result[0]["id"] == 123
    assert result[0]["code"] == "ABC123"  # Not a number
    assert result[0]["value"] == 456.78


def test_empty_fields():
    """Test handling of empty fields."""
    csv_content = """name,age,city
John,,NYC
,25,LA"""

    result = parse_csv(csv_content)

    assert result[0]["name"] == "John"
    assert result[0]["age"] == ""
    assert result[0]["city"] == "NYC"
    assert result[1]["name"] == ""
    assert result[1]["age"] == 25


def test_negative_numbers():
    """Test handling of negative numbers."""
    csv_content = """temperature,balance,elevation
-5,-100.50,-200"""

    result = parse_csv(csv_content)

    assert result[0]["temperature"] == -5
    assert result[0]["balance"] == -100.50
    assert result[0]["elevation"] == -200


def test_large_dataset():
    """Test parsing larger CSV dataset."""
    rows = ["id,value"]
    for i in range(100):
        rows.append(f"{i},{i * 10}")

    csv_content = "\n".join(rows)
    result = parse_csv(csv_content)

    assert len(result) == 100
    assert result[0] == {"id": 0, "value": 0}
    assert result[99] == {"id": 99, "value": 990}
