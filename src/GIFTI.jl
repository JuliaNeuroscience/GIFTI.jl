module GIFTI

using LightXML
using GeometryBasics
using CodecZlib: transcode, GzipDecompressor
using Base64: base64decode
using LinearAlgebra

load(io::IO) = parse_gifti_mesh(parse_string(read(io, String)))
load(fname::String) = parse_gifti_mesh(parse_file(fname))

function parse_nifti_datatype(Tstr::String)
    if Tstr == "NIFTI_TYPE_INT32"
        Int32
    elseif Tstr == "NIFTI_TYPE_FLOAT32"
        Float32
    elseif Tstr == "NIFTI_TYPE_INT64"
        Int64
    elseif Tstr == "NIFTI_TYPE_FLOAT64"
        Float64
    else
        error("Unhandled data type: $(attribute(xml, "DataType"))")
    end
end

parse_nifti_datatype(xml::XMLElement) = parse_nifti_datatype(attribute(xml, "DataType"))

function parse_nifti_array_size(xml)
    N = parse(Int, attribute(xml, "Dimensionality"))
    ntuple(i -> parse(Int, attribute(xml, "Dim$(i-1)")), N)
end

function parse_nifti_array_data(xml::XMLElement)
    data_blobs = get_elements_by_tagname(xml, "Data")
    if length(data_blobs) == 0
        error("Could not find any `Data` elements")
    elseif length(data_blobs) > 1
        warn("Found multiple `Data` elements, using only the first one.")
    end
    data = content(first(data_blobs))
    encoding = attribute(xml, "Encoding")
    if encoding == "GZipBase64Binary"
        gzbytes = base64decode(data)
        return transcode(GzipDecompressor, gzbytes)
    elseif encoding == "Base64Binary"
    	return base64decode(data)
    else
        error("Unhandled encoding: $encoding")
    end
end

function parse_nifti_data_array(xml)
    T = parse_nifti_datatype(xml)
    dims = parse_nifti_array_size(xml)
    data = parse_nifti_array_data(xml)
    order = attribute(xml, "ArrayIndexingOrder")
    if order == "RowMajorOrder"
        array = reshape(reinterpret(T, data), reverse(dims))
    else
        @assert order = "ColumnMajorOrder"
        array = reshape(reinterpret(T, data), dims)
    end
    endian = attribute(xml, "Endian")
    if endian == "LittleEndian"
        array .= ltoh.(array)
    else
        @assert endian == "BigEndian"
        array .= btoh.(array)
    end
    array
end

function parse_gifti_mesh(xml::XMLElement)
    arrays = get_elements_by_tagname(xml, "DataArray");
    pointset_arrays = filter(get_elements_by_tagname(xml, "DataArray")) do arr
        attribute(arr, "Intent") == "NIFTI_INTENT_POINTSET"
    end
    if length(pointset_arrays) == 0
        error("Could not find any arrays with intent NIFTI_INTENT_POINTSET")
    elseif length(pointset_arrays) > 1
        warn("Found multiple pointset arrays, using only the first.")
    end
    pointset = first(pointset_arrays)

    triangle_arrays = filter(get_elements_by_tagname(xml, "DataArray")) do arr
        attribute(arr, "Intent") == "NIFTI_INTENT_TRIANGLE"
    end
    if length(triangle_arrays) == 0
        error("Could not find any arrays with intent NIFTI_INTENT_TRIANGLE")
    elseif length(triangle_arrays) > 1
        warn("Found multiple triangle arrays, using only the first.")
    end
    triangles = first(triangle_arrays);

    vert_array = parse_nifti_data_array(pointset) ./ 100
    face_array = parse_nifti_data_array(triangles)

    vertices = reshape(reinterpret(Point3f0, vert_array), (size(vert_array, 2),))
    faces = [TriangleFace(face) for face in eachcol(reinterpret(OffsetInteger{-1, Int32}, face_array))]
    GeometryBasics.Mesh(meta(vertices; normals=normalize.(vertices)), faces)
end

parse_gifti_mesh(doc::XMLDocument) = parse_gifti_mesh(root(doc))

end
