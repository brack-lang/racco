from std/htmlgen import nil
import brack/api
import brack/ast

macro iframe* (e: varargs[untyped]): untyped =
  result = htmlgen.xmlCheckedTag(
    e, "iframe",
    "src srcdoc name sandbox width height loading frameborder allow allowfullscreen" & htmlgen.commonAttr
  )

brackModule(Html):
  proc youtube* (url: string): string {.curly: "youtube".} =
    result = iframe(
      src=url, width="100%", height="500",
      title="YouTube video player",
      frameborder="0",
      allowfullscreen="",
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    )
  
  proc spotify* (url: string): string {.curly: "spotify".} =
    result = iframe(
      src=url, width="100%", height="380",
      style="border-radius:12px",
      frameBorder="0", allowfullscreen="",
      allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture",
      loading="lazy"
    )

  proc video* (src: string): string {.curly: "video".} =
    result = htmlgen.video(
      htmlgen.source(
        src=src, `type`="video/mp4"
      ),
      controls="",
      width="100%"
    )
