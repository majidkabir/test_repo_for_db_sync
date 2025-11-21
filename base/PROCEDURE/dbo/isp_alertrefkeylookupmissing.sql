SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Stored Procedure: isp_AlertRefKeyLookUpMissing                       */          
/* Creation Date: 01-May-2012                                           */          
/* Copyright: IDS                                                       */          
/* Written by: SHONG                                                    */          
/*                                                                      */          
/* Purpose: Alert Setup Issue for Missing RefKeyLookUp                  */          
/*                                                                      */          
/*                                                                      */          
/* Called By: ALT - RefKeyLookUp Missing                                */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 5.4                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author Ver Purposes                                     */   
/* 21 Jan 2014  TLTING 1.1 All Storer                                   */   
/*                                                                      */          
/************************************************************************/          
          
CREATE PROC [dbo].[isp_AlertRefKeyLookUpMissing]          
(   
  @cStorerKey      NVARCHAR(15) = '%',  
  @RecipientList   NVARCHAR(max),    
  @ccRecipientList NVARCHAR(max)  
)    
AS          
BEGIN        
        
SET NOCOUNT ON        
SET QUOTED_IDENTIFIER OFF        
SET ANSI_WARNINGS ON     
SET ANSI_NULLS ON    
SET CONCAT_NULL_YIELDS_NULL OFF        
        
DECLARE @bodyText       NVARCHAR(MAX),     
        @cSQL           NVARCHAR(MAX),    
        @nFG            INT,    
        @nFE            INT,    
        @emailSubject   NVARCHAR(MAX),     
        @cDate          NVARCHAR(20)    
  
SET @cDate = Convert(VARCHAR(10), DateAdd(day, -2, getdate()), 103)       
SET @emailSubject = 'RefKeyLookUp Missing ' + @cDate    


--SELECT p.StorerKey, p.PickDetailKey, p.PickSlipNo, p.OrderKey, p.OrderLineNumber, o.LoadKey   
--INTO #TempPickDetail  
--FROM PICKDETAIL p (NOLOCK)   
--JOIN ORDERDETAIL o (NOLOCK) ON o.OrderKey = p.OrderKey AND o.OrderLineNumber = p.OrderLineNumber   
--LEFT OUTER JOIN RefKeyLookup rkl (NOLOCK) ON rkl.PickDetailkey = p.PickDetailKey   
--WHERE rkl.PickDetailkey IS NULL    
--AND p.STATUS < '9'  
--AND p.OrderKey IN (  
--SELECT DISTINCT OrderKey   
--FROM RefKeyLookup WITH (NOLOCK)  
--)   
CREATE TABLE #TempPickDetail 
(  ROWREF   INT NOT NULL Identity(1,1) Primary Key,
   StorerKey   NVARCHAR(15),
   PickDetailKey   NVARCHAR(10),
   PickSlipNo   NVARCHAR(10),
   OrderKey   NVARCHAR(10),
   OrderLineNumber   NVARCHAR(5),
   LoadKey   NVARCHAR(10)

)


IF @cStorerKey = '%'
BEGIN
   INSERT INTO #TempPickDetail (StorerKey, PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey )
   SELECT p.StorerKey, p.PickDetailKey, p.PickSlipNo, p.OrderKey, p.OrderLineNumber, o.LoadKey   
   FROM PICKDETAIL p (NOLOCK)   
   JOIN ORDERDETAIL o (NOLOCK) ON o.OrderKey = p.OrderKey AND o.OrderLineNumber = p.OrderLineNumber   
   JOIN PICKHEADER PH (NOLOCK) ON PH.PickHeaderKey = P.PickSlipNo AND PH.Zone = 'LP'  
   LEFT OUTER JOIN RefKeyLookup rkl (NOLOCK) ON rkl.PickDetailkey = p.PickDetailKey   
   WHERE rkl.PickDetailkey IS NULL    
   AND P.PickSlipNo IS NOT NULL   
   AND P.PickSlipNo <> ''   
   AND p.STATUS < '9'   
   AND P.Qty > 0    
   ORDER BY p.StorerKey, p.PickDetailKey
END 
ELSE
BEGIN  
   INSERT INTO #TempPickDetail (StorerKey, PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber, LoadKey )
   SELECT p.StorerKey, p.PickDetailKey, p.PickSlipNo, p.OrderKey, p.OrderLineNumber, o.LoadKey   
   FROM PICKDETAIL p (NOLOCK)   
   JOIN ORDERDETAIL o (NOLOCK) ON o.OrderKey = p.OrderKey AND o.OrderLineNumber = p.OrderLineNumber   
   JOIN PICKHEADER PH (NOLOCK) ON PH.PickHeaderKey = P.PickSlipNo AND PH.Zone = 'LP'  
   LEFT OUTER JOIN RefKeyLookup rkl (NOLOCK) ON rkl.PickDetailkey = p.PickDetailKey   
   WHERE rkl.PickDetailkey IS NULL    
   AND P.PickSlipNo IS NOT NULL   
   AND P.PickSlipNo <> ''   
   AND p.STATUS < '9'   
   AND p.Storerkey = @cStorerKey   
   AND P.Qty > 0    
   ORDER BY p.PickDetailKey
END  
  
    
IF EXISTS (SELECT 1 FROM #TempPickDetail)    
BEGIN    
    
      SET @bodyText = @bodyText + N'Missing RefKeyLookUp' +    
          N'<table border="1" cellspacing="0" cellpadding="5">' +    
          N'<tr bgcolor=yellow><th>Storer</th><th>PickDetailKey</th><th>PickSlipNo</th>' +    
          N'<th>Order Key</th><th>Order Line</th><th>Load Key</th></tr>' +    
          CAST ( ( SELECT td = ISNULL(CAST(StorerKey AS NVARCHAR(99)),''), '',    
                          td = ISNULL(CAST(PickDetailKey AS NVARCHAR(99)),''), '',    
                          td = ISNULL(CAST(PickSlipNo AS NVARCHAR(99)),''), '',  
                          td = ISNULL(CAST(OrderKey AS NVARCHAR(99)),''), '',  
                          td = ISNULL(CAST(OrderLineNumber AS NVARCHAR(99)),''), '',    
                          td = ISNULL(CAST(LoadKey AS NVARCHAR(99)),''), ''    
                   FROM #TempPickDetail    
              FOR XML PATH('tr'), TYPE       
          ) AS NVARCHAR(MAX) ) + N'</table><br>' ;      
    
   DROP TABLE #TempPickDetail;    
    
   SET @bodyText = REPLACE(REPLACE(@bodyText,'&lt;','<'),'&gt;','>')    
    
   EXEC msdb.dbo.sp_send_dbmail     
    @recipients      = @recipientList,    
    @copy_recipients = @ccRecipientList,    
    @subject         = @emailSubject,    
    @body            = @bodyText,    
    @body_format     = 'HTML' ;     
    
END    
    
set nocount off     
END -- procedure  

GO