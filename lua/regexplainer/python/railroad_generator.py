#!/usr/bin/env python3
"""
Railroad diagram generator for nvim-regexplainer.
Converts regexplainer component tree to railroad diagrams using the railroad-diagrams library.
"""

import sys
import json
import base64
import io
from typing import Any, Dict, List, Optional, Union

try:
    from railroad import *
    from PIL import Image
    import cairosvg
except ImportError as e:
    print(f"Error: Missing required Python packages: {e}", file=sys.stderr)
    print("Please install: pip install railroad-diagrams Pillow cairosvg", file=sys.stderr)
    sys.exit(1)


class RailroadDiagramGenerator:
    """Generates railroad diagrams from regexplainer component trees."""
    
    def __init__(self, width: int = 800, height: int = 600, dark_theme: bool = True):
        self.width = width
        self.height = height
        self.dark_theme = dark_theme
    
    def component_to_railroad(self, component: Dict[str, Any]) -> Any:
        """Convert a regexplainer component to a railroad diagram element."""
        comp_type = component.get('type', '')
        text = component.get('text', '')
        children = component.get('children', [])
        
        # Handle quantifiers
        optional = component.get('optional', False)
        zero_or_more = component.get('zero_or_more', False)
        one_or_more = component.get('one_or_more', False)
        quantifier = component.get('quantifier')
        
        # Base element
        element = None
        
        if comp_type == 'pattern_character':
            element = Terminal(text)
        elif comp_type == 'character_class':
            if component.get('negative'):
                element = Terminal(f"[^{text[2:-1]}]")
            else:
                element = Terminal(text)
        elif comp_type == 'start_assertion':
            element = Terminal('^')
        elif comp_type == 'end_assertion':
            element = Terminal('$')
        elif comp_type == 'boundary_assertion':
            element = Terminal(text)
        elif comp_type == 'identity_escape':
            element = Terminal(text)
        elif comp_type == 'character_class_escape':
            element = Terminal(text)
        elif comp_type == 'control_escape':
            element = Terminal(text)
        elif comp_type == 'decimal_escape':
            element = Terminal(text)
        elif comp_type in ['anonymous_capturing_group', 'named_capturing_group']:
            if children:
                child_elements = [self.component_to_railroad(child) for child in children]
                if len(child_elements) == 1:
                    element = Group(child_elements[0], component.get('group_name', f"group {component.get('capture_group', '')}"))
                else:
                    element = Group(Sequence(*child_elements), component.get('group_name', f"group {component.get('capture_group', '')}"))
            else:
                element = Group(Terminal(''), component.get('group_name', f"group {component.get('capture_group', '')}"))
        elif comp_type == 'non_capturing_group':
            if children:
                child_elements = [self.component_to_railroad(child) for child in children]
                if len(child_elements) == 1:
                    element = child_elements[0]
                else:
                    element = Sequence(*child_elements)
            else:
                element = Terminal('')
        elif comp_type == 'alternation':
            if children:
                child_elements = [self.component_to_railroad(child) for child in children]
                element = Choice(0, *child_elements)
            else:
                element = Terminal('')
        elif comp_type == 'lookaround_assertion':
            direction = component.get('direction', 'ahead')
            negative = component.get('negative', False)
            prefix = '?<!' if direction == 'behind' and negative else \
                    '?<=' if direction == 'behind' else \
                    '?!' if negative else '?='
            
            if children:
                child_elements = [self.component_to_railroad(child) for child in children]
                if len(child_elements) == 1:
                    element = Group(child_elements[0], prefix)
                else:
                    element = Group(Sequence(*child_elements), prefix)
            else:
                element = Terminal(f"({prefix})")
        elif comp_type in ['pattern', 'term', 'root']:
            if children:
                child_elements = [self.component_to_railroad(child) for child in children]
                if len(child_elements) == 1:
                    element = child_elements[0]
                else:
                    element = Sequence(*child_elements)
            else:
                element = Terminal('')
        else:
            # Fallback for unknown types
            element = Terminal(text or comp_type)
        
        # Apply quantifiers
        if element:
            if zero_or_more:
                element = ZeroOrMore(element)
            elif one_or_more:
                element = OneOrMore(element)
            elif optional:
                element = Optional(element)
            elif quantifier:
                element = Group(element, quantifier)
        
        return element or Terminal('')
    
    def calculate_font_size(self) -> int:
        """Calculate appropriate font size based on image dimensions and constraints."""
        # For small images (like 76x20), we need to scale font size appropriately
        # Aim for font that's readable but fits the diagram
        
        # Base font size calculation
        if self.width <= 100 or self.height <= 30:
            # Very small images - use tiny font
            return 6
        elif self.width <= 200 or self.height <= 60:
            # Small images - use small font
            return 8
        elif self.width <= 400 or self.height <= 150:
            # Medium images - use medium font
            return 10
        else:
            # Large images - use normal font
            return 12

    def components_to_diagram(self, components: List[Dict[str, Any]]) -> Any:
        """Convert a list of components to a complete railroad diagram."""
        if not components:
            return Diagram(Terminal(''))
        
        # Set appropriate font size for railroad diagrams
        font_size = self.calculate_font_size()
        
        # Configure railroad diagram styling
        # This would require extending the railroad-diagrams library
        # For now, we'll rely on CSS styling in SVG
        
        elements = []
        for component in components:
            element = self.component_to_railroad(component)
            if element:
                elements.append(element)
        
        if len(elements) == 1:
            return Diagram(elements[0])
        else:
            return Diagram(Sequence(*elements))
    
    def apply_dark_theme_styles(self, svg_data: str) -> str:
        """Apply dark theme CSS styles to SVG data with dynamic font sizing."""
        if not self.dark_theme:
            return svg_data
        
        # Calculate appropriate font size
        font_size = self.calculate_font_size()
        
        # Define dark theme CSS with dynamic font size
        dark_css = f"""
        <style type="text/css">
        path {{
            stroke: #e0e0e0 !important;
            fill: none !important;
            stroke-width: 1.5px !important;
        }}
        text {{
            fill: #e0e0e0 !important;
            font-family: monospace !important;
            font-size: {font_size}px !important;
            font-weight: 500 !important;
        }}
        rect {{
            fill: #2d2d2d !important;
            stroke: #e0e0e0 !important;
            stroke-width: 1.5px !important;
        }}
        circle {{
            fill: #2d2d2d !important;
            stroke: #e0e0e0 !important;
            stroke-width: 1.5px !important;
        }}
        g.terminal rect {{
            fill: #3a3a3a !important;
            stroke: #e0e0e0 !important;
        }}
        g.nonterminal rect {{
            fill: #4a4a4a !important;
            stroke: #e0e0e0 !important;
        }}
        </style>
        """
        
        # Insert CSS after the SVG opening tag
        svg_start = svg_data.find('>')
        if svg_start != -1:
            svg_data = svg_data[:svg_start + 1] + dark_css + svg_data[svg_start + 1:]
        
        return svg_data

    def trim_image_with_margin(self, png_data: bytes) -> bytes:
        """Trim the image to content with a small vertical margin."""
        try:
            # Load the PNG data as a PIL image
            import io
            img = Image.open(io.BytesIO(png_data))
            
            # Convert to RGBA to handle transparency
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Get the bounding box of non-transparent content
            bbox = img.getbbox()
            if bbox is None:
                # If no content, return original
                return png_data
            
            # Add small vertical margin (5% of height, minimum 10px)
            margin_v = max(10, int((bbox[3] - bbox[1]) * 0.05))
            margin_h = max(5, int((bbox[2] - bbox[0]) * 0.02))  # Small horizontal margin too
            
            # Expand bounding box with margin, but don't exceed original image bounds
            new_bbox = (
                max(0, bbox[0] - margin_h),
                max(0, bbox[1] - margin_v),
                min(img.width, bbox[2] + margin_h),
                min(img.height, bbox[3] + margin_v)
            )
            
            # Crop to the new bounding box
            trimmed_img = img.crop(new_bbox)
            
            # Convert back to bytes
            output_buffer = io.BytesIO()
            trimmed_img.save(output_buffer, format='PNG')
            return output_buffer.getvalue()
            
        except Exception as e:
            # If trimming fails, return original data
            return png_data

    def generate_png(self, components: List[Dict[str, Any]]) -> str:
        """Generate a PNG image from components and return as base64 string."""
        try:
            # All debug output should go to stderr
            # print(f"DEBUG: Generating image at {self.width}x{self.height} pixels", file=sys.stderr)
            diagram = self.components_to_diagram(components)
            
            # Generate SVG
            import io
            svg_buffer = io.StringIO()
            diagram.writeStandalone(svg_buffer.write)
            svg_data = svg_buffer.getvalue()
            
            # Apply dark theme if requested
            svg_data = self.apply_dark_theme_styles(svg_data)
            
            # Convert SVG to PNG using cairosvg with transparent background
            png_data = cairosvg.svg2png(
                bytestring=svg_data.encode('utf-8'),
                output_width=self.width,
                output_height=self.height,
                background_color=None  # Transparent background
            )
            
            # Trim the image and add small margin
            png_data = self.trim_image_with_margin(png_data)
            
            # Debug: Check final image size after trimming
            import io
            final_img = Image.open(io.BytesIO(png_data))
            # print(f"DEBUG: Final image size after trimming: {final_img.width}x{final_img.height} pixels", file=sys.stderr)
            
            # Encode as base64
            return base64.b64encode(png_data).decode('ascii')
            
        except Exception as e:
            # Return error as base64 encoded text image
            error_msg = f"Error generating diagram: {str(e)}"
            print(error_msg, file=sys.stderr)
            
            # Create a simple error image with transparent background
            img = Image.new('RGBA', (self.width, self.height), color=(0, 0, 0, 0))
            png_buffer = io.BytesIO()
            img.save(png_buffer, format='PNG')
            return base64.b64encode(png_buffer.getvalue()).decode('ascii')


def main():
    """Main entry point for the script."""
    if len(sys.argv) < 2:
        print("Usage: railroad_generator.py <components_json> [width] [height] [dark_theme]", file=sys.stderr)
        sys.exit(1)
    
    try:
        components_json = sys.argv[1]
        width = int(sys.argv[2]) if len(sys.argv) > 2 else 800
        height = int(sys.argv[3]) if len(sys.argv) > 3 else 600
        dark_theme = sys.argv[4].lower() == 'true' if len(sys.argv) > 4 else True  # Default to dark theme
        
        components = json.loads(components_json)
        
        generator = RailroadDiagramGenerator(width, height, dark_theme)
        png_base64 = generator.generate_png(components)
        
        print(png_base64)
        
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()