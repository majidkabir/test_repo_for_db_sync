SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_RPT_RP_TALLYSHT_001                            */
/* Creation Date: 2023-03-21                                            */
/* Copyright: LFL                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21973 IND REIND Tally Sheet New/CR                      */
/*                                                                      */
/* Called By: isp_RPT_RP_TALLYSHT_001                                   */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 21-MAR-2023  CSCHONG 1.0   Devops Scripts Combine                    */
/************************************************************************/

CREATE   PROC [dbo].[isp_RPT_RP_TALLYSHT_001] (
                                                   @c_ReceiptkeyStart NVARCHAR(10),
                                                   @c_ReceiptkeyEnd   NVARCHAR(10),
                                                   @c_StorerkeyStart  NVARCHAR(15),
                                                   @c_StorerkeyEnd    NVARCHAR(15)
   )
 AS
 BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


DECLARE @cDataWidnow NVARCHAR(40)
SET @cDataWidnow = 'RPT_RP_TALLYSHT_001'

SELECT Storerkey         = RH.Storerkey
     , Facility          = RH.Facility
    , ReceiptKey        = RH.ReceiptKey
    , ExternReceiptKey  = RH.ExternReceiptKey
    , POKey             = RH.POKey
    , SellerName        = RH.SellerName
    , ReceiptLineNumber = RD.ReceiptLineNumber
    , Sku               = RD.Sku
    , AltSku            = SKU.AltSku
    , QtyExpected       = RD.QtyExpected
    , CBM               = (SKU.Length/1000.0) * (SKU.Width/1000.0) * (SKU.Height / 1000.0)
    , PF_Exist          = CASE WHEN EXISTS(SELECT TOP 1 1 FROM SKUxLOC (NOLOCK) WHERE Storerkey=RD.Storerkey AND Sku=RD.Sku AND LocationType='PICK') THEN 'Y' ELSE 'N' END
    , PF_Loc            = ISNULL((SELECT TOP 1 Loc FROM SKUxLOC (NOLOCK) WHERE Storerkey=RD.Storerkey AND Sku=RD.Sku AND LocationType='PICK' ORDER BY 1), '')
     , Datawindow        = @cDataWidnow
     , T_ReportTitle     = CAST( RTRIM( (select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_ReportTitle') ) AS NVARCHAR(500))
     ,NoofPallet        = RH.NoOfPallet
     ,Sdescr            = SKU.DESCR
     ,UOM               = RD.UOM
     ,SColor            =SKU.Color
     ,[Length]          =sku.length 
     ,[width]           =sku.width 
     ,[height]          =sku.height 
     ,[KG]              = sku.STDGrosswgt     
  FROM dbo.RECEIPT       RH (NOLOCK)
  JOIN dbo.RECEIPTDETAIL RD (NOLOCK) ON RH.ReceiptKey = RD.ReceiptKey
  JOIN dbo.SKU          SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku

  LEFT JOIN (
     SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
          , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
       FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@cDataWidnow AND Short='Y'
  ) RptCfg3
  ON RptCfg3.Storerkey=RH.Storerkey AND RptCfg3.SeqNo=1

  -- WHERE ( RECEIPT.ReceiptKey = @c_Receiptkey )
    WHERE ( RH.ReceiptKey >= @c_ReceiptkeyStart ) AND
        ( RH.ReceiptKey <= @c_ReceiptkeyEnd) AND
        ( RH.Storerkey >= @c_StorerkeyStart ) AND
        ( RH.Storerkey <= @c_StorerkeyEnd )

 ORDER BY ReceiptKey, ReceiptLineNumber

  

END

GO