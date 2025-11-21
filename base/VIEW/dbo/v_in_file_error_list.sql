SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE VIEW [dbo].[V_IN_FILE_ERROR_LIST]
AS

 SELECT --top 1000
       --distinct --top 10 
	   ITFCFG.descr ,
       InLine.File_key , InLine.DataStream , 
	   --InLine.FileName , 
	   CASE WHEN CHARINDEX('_',InLine.Filename) > 0
            THEN RIGHT( REPLACE(InLine.Filename,'.txt','.xml') , LEN(InLine.Filename) - CHARINDEX('_',InLine.Filename))
            ELSE InLine.filename
       END [FileName] , 
	   CASE 
	        WHEN CHARINDEX('NSQL68032' , InLine.ErrMsg ) > 0 -- NSQL68030 - IBS failure , IBD missing.
			     AND CHARINDEX('Non-existent of IBD' , InLine.ErrMsg ) > 0
			     THEN 'IBS Importing failure: IBS ' + Rtrim(Isnull(Pur.UserDefine09,'')) + ' Missing IBD ' + Rtrim(IsNull(Pur.UserDefine05,'')) 
		    WHEN InLine.FileName LIKE 'WMSORD_I215_%' AND CHARINDEX('Failed. SKU:' , InLine.ErrMsg ) > 0
			     THEN 'Customer Order Importing failure: Order ' + Rtrim(isnull(So.ExternOrderKey,'')) + ' Missing SKU ' + Rtrim(Isnull(So.Sku,''))
			ELSE ErrMsg
	   End [ErrMsgs] ,
	   --InLine.ErrMsg [ErrMsg_Org] , 
	   --InLine.LineTextUnicode ,
	   InLine.addDate
	   --format(InLine.addDate,'dd/MM/yyyy') [Date] 
  FROM GBRDTSITF..itfconfig(nolock) ITFCFG
  JOIN GBRDTSITF..in_line(nolock) InLine
    ON ITFCFG.descr LIKE '%H_M%' 
   AND ITFCFG.DataStream = InLine.DataStream
  LEFT JOIN GBRDTSITF..V_0000_GENERIC_PUR_DET_UNICODE(nolock) Pur
    ON InLine.File_Key = Pur.File_Key
   AND InLine.DataStream = Pur.DataStream
   AND InLine.SeqNo = Pur.SeqNo
  LEFT JOIN GBRDTSITF..V_0000_GENERIC_ORD_DET_UNICODE(nolock) SO
    on InLine.File_Key = So.File_Key
   AND InLine.SeqNo = So.SeqNo
   AND InLine.DataStream = So.DataStream
 WHERE IsNull(InLine.errmsg,'') <> '' 
   AND InLine.Status = '5'
   AND InLine.errmsg NOT LIKE '<WARNING>%'
   AND SUBSTRING( InLine.LineTextUnicode , 4 , 1 ) = 'D'
   AND InLine.addDate BETWEEN 
        DATEADD( day , -1 , CAST( CONVERT(char(10) , GETDATE() ,121) + ' ' + '00:00' AS DATETIME ) ) AND
        DATEADD( day , -1 , CAST( CONVERT(char(10) , GETDATE() ,121) + ' ' + '23:59' AS DATETIME ) ) 

GO