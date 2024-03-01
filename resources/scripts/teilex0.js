window.addEventListener("WebComponentsReady", () => {
    const pbCode = document.getElementById("code-highlight");
    const view =  document.getElementById("view1");


    if(pbCode != null) {
        window.pbEvents.subscribe("pb-end-update", "transcription", (ev) => {
            const doc = view.getDocument();
            if (doc && doc.path) {
                const queryString = ev.currentTarget.location.search;
                const urlParams = new URLSearchParams(queryString);
                urlParams.append("doc", encodeURIComponent(doc.path));
                loadXml(view.getEndpoint(), urlParams, pbCode)
            }
        });
    }
    
    });

    function loadXml(endpoint, urlParams, pbCode) {
        let url = `${endpoint}/api/parts/${urlParams.get('doc')}/xml?view=${urlParams.get('view')}&root=${urlParams.get('root')}`;
        let xml = "<empty />";
        
        return new Promise((resolve, reject) => {
            fetch(url, {
                        method: "GET",
                        mode: "cors",
                        credentials: "same-origin",
                        headers: {
							"Content-Type": "application/xml",
						}
                    })
                    .then(response=>response.text())
                    .then(data=>{
                        let parser = new DOMParser();
                        let xml = parser.parseFromString(data, "application/xml");
                        pbCode.code = data;
                    });
                });
               
    }