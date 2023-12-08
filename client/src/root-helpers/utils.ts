function copyToClipboard (text: string) {
  const el = document.createElement('textarea')
  el.value = text
  el.setAttribute('readonly', '')
  el.style.position = 'absolute'
  el.style.left = '-9999px'
  document.body.appendChild(el)
  el.select()
  document.execCommand('copy')
  document.body.removeChild(el)
}

function wait (ms: number) {
  return new Promise<void>(res => {
    setTimeout(() => res(), ms)
  })
}

//-------------------------------------------------------------------------------------------------
// VBML
//-------------------------------------------------------------------------------------------------

function readFileContent(file: File): Promise<string>
{
  return new Promise<string>((res, rej) =>
  {
    const reader = new FileReader()

    reader.onload = (e) => { res(reader.result.toString()) }

    reader.readAsText(file)
  })
}

function getVbmlValue(text: string, key: string)
{
  let indexA = text.indexOf(key + ": ");

  if (indexA == -1) return "";

  indexA += key.length + 2;

  var indexB = text.indexOf('\n', indexA);

  if (indexB == -1) return "";

  return text.substring(indexA, indexB).trim();
}

//-------------------------------------------------------------------------------------------------

export {
  copyToClipboard,
  wait,
  //-----------------------------------------------------------------------------------------------
  // VBML
  readFileContent,
  getVbmlValue
}
