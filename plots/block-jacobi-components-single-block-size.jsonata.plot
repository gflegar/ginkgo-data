(
"Parameters: ";
$systems := {
    "daint-P100-PCIe": "baseline (DP)",
    "daint-P100-PCIe-cms": "column-major (DP)",
    "daint-P100-PCIe-i": "interleaved (DP)"
};

$element_sizes := {
    "daint-P100-PCIe": 8,
    "daint-P100-PCIe-cms": 8,
    "daint-P100-PCIe-i": 8,
    "daint-P100-PCIe-sp": 4,
    "daint-P100-PCIe-cms-sp": 4,
    "daint-P100-PCIe-i-sp": 4
};

$block_size := [1][0];
$num_blocks := [50000][0];
$component := ["find_blocks", "generate", "simple_apply"][2];

$stage := {
    "find_blocks": "generate",
    "generate": "generate",
    "simple_apply": "apply"
}~>$lookup($component);

$getColor := function($num_colors, $id) {
  "hsl(" & $floor(360 * $id / $num_colors) & ",40%,55%)"
};

$flops := function($component, $num_blocks, $block_size) {
    $component = "generate" ? (2 * ($block_size~>$power(3)) * $num_blocks) :
    $component = "simple_apply" ? ( 2 * ($block_size~>$power(2)) * $num_blocks) :
    (($block_size~>$power(2)) * $num_blocks)
};

$data := function($component, $num_blocks, $block_size, $esize) {
    $component = "generate" ? (($block_size~>$power(2)) * $num_blocks * (4 + 3 *  $esize)) :
    $component = "simple_apply" ? ((($block_size~>$power(2)) * $esize + 3 * $block_size * $esize) * $num_blocks) :
    (($block_size~>$power(2)) * $num_blocks * (4 + 3 *  $esize))
};

$filter_result := function($dataset, $block_size) {
($dataset[problem.block_size=$block_size].{
    "num_blocks": problem.num_blocks,
    "preconditioner": preconditioner
})^(num_blocks)
};

$extract_performance := function($transformed) {
    $transformed.(
        ($component~>$flops(num_blocks, $block_size)) /
        (((preconditioner~>$lookup("jacobi-" & $block_size))~>$lookup($stage))
            .components~>$lookup($component))
    )
};

$extract_data := function($transformed, $system) {
    $transformed.(
        ($component~>$data($num_blocks, block_size, $element_sizes~>$lookup($system))) /
        (((preconditioner~>$lookup("jacobi-" & block_size))~>$lookup($stage))
            .components~>$lookup($component))
    )
};

$dsize := $systems~>$keys()~>$count();
$datasets := $systems~>$keys()~>$map(function ($v, $i) {
    {
        "label": $systems~>$lookup($v),
        "data":  $$.content[dataset.system=$v]~>$filter_result($block_size)
                    ~>$extract_performance(),
        "borderColor": $getColor($dsize, $i),
        "backgroundColor": $getColor($dsize, $i),
        "fill": false
    }
});

{
    "metadata_": {
        "systems": content.dataset.system.{ $: null }~>$keys()
    },
    "type": "line",
    "data": {
        "labels": content.problem[block_size=$block_size].num_blocks.{ $string($): null}~>$keys(),
        "datasets": $datasets~>$append([])
    },
    "options": {
        "title": {
            "display": true,
            "text": $system & " performance of '" &
                    $component & "' step of '" & $stage & "' stage - block size: " &
                    $block_size
        },
        "scales": {
            "xAxes": [{
                "scaleLabel": {
                    "display": true,
                    "labelString": "# blocks"
                }
            }],
            "yAxes": [{
                "scaleLabel": {
                    "display": true,
                    "labelString": "GFlop/s"
                },
                "ticks": {
                    "min": 0
                }
            }]
        },
        "tooltips": { "mode": "index" }
    }
}
)
