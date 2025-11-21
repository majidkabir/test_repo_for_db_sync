SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_ASN_GINCTN_001                                */    
/* Creation Date: 10-JUNE-2022                                             */    
/* Copyright: LFL                                                          */    
/* Written by: Harshitha                                                   */    
/*                                                                         */    
/* Purpose: WMS-19769                                                      */    
/*                                                                         */    
/* Called By: RPT_ASN_GINCTN_001                                           */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */    
/*                                                                         */    
/* Version: 1.0                                                            */    
/*                                                                         */    
/* Data Modifications:                                                     */    
/*                                                                         */    
/* Updates:                                                                */    
/* Date            Author   Ver  Purposes                                  */
/* 13-Jun-2022     WLChooi  1.0  DevOps Combine Script                     */
/* 15-Jun-2023     CSCHONG  1.1  WMS-22731 add new field  (CS01)           */
/***************************************************************************/                
              
CREATE   PROC [dbo].[isp_RPT_ASN_GINCTN_001]          
       @c_Receiptkey        NVARCHAR(10)              
                                 
AS                          
BEGIN                          
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF                  
                   
  
   DECLARE @c_pickheaderkey        NVARCHAR(10),  
           @n_continue             INT,  
           @c_errmsg               NVARCHAR(255),  
           @b_success              INT,  
           @n_err                  INT,  
           @n_pickslips_required   INT,  
           @n_SortBySkuLoc         INT   
  
   CREATE TABLE #InwardNotesCtn02  
   (      Company             NVARCHAR(45),  
          ReceiptKey          NVARCHAR(20) NULL,  
          CarrierReference    NVARCHAR(18) NULL,  
          StorerKey           NVARCHAR(15) NULL,  
          CarrierName         NVARCHAR(30) NULL,  
          AddWho              NVARCHAR(18) NULL,  
          ReceiptDate         DATETIME NULL,  
          Sku                 NVARCHAR(20)  NULL,  
          Lottable02          NVARCHAR(18) NULL,  
          DESCR               NVARCHAR(60) NULL,  
          Lottable04          DATETIME NULL,  
          UOM                 NVARCHAR(10) NULL,  
          QtyExp              INT,  
          QtyRec              INT,  
          STDCUBE             FLOAT,  
          RECNOTES            NVARCHAR(60) NULL,  
          CarrierAddress1     NVARCHAR(45) NULL,  
          POkey               NVARCHAR(18) NULL,  
          CaseCnt             INT,  
          Lottable03          NVARCHAR(18) NULL,  
          RHSignatory         NVARCHAR(18) NULL,  
          Userdefine01        NVARCHAR(30) NULL,  
          Facility            NVARCHAR(15) NULL,  
          Externreceiptkey    NVARCHAR(20) NULL,  
          lottable01          NVARCHAR(18) NULL,  
          Containerkey        NVARCHAR(18) NULL,  
          conditiondesc       NVARCHAR(250) NULL,  
          containertype       NVARCHAR(250) NULL,  
          Signatory           NVARCHAR(30) NULL,  
          SortByLOTT02        INT        NULL,  
          ShowLot15           INT NULL,  
          Lottable15          DATETIME NULL,    
          SortByLOTT01        INT      NULL,     
          Showlogo            INT,               
          ShowLottable06      INT,             
          Lottable06          NVARCHAR(30),      
          ConditionCode       NVARCHAR(10),    
          Showgin             NVARCHAR(10),
          ShowLottable0708    INT,
          Lottable07          NVARCHAR(30), 
          Lottable08          NVARCHAR(30)
)      --CS01   
  
   SELECT Storerkey,  
          SortByLOTT02   = ISNULL(MAX(CASE WHEN Code = 'SORTBYLOTT02'  THEN 1 ELSE 0 END),0)  
         ,ShowLot15      = ISNULL(MAX(CASE WHEN Code = 'SHOWLOT15'  THEN 1 ELSE 0 END),0)        
         ,SortByLOTT01   = ISNULL(MAX(CASE WHEN Code = 'SORTBYLOTT01'  THEN 1 ELSE 0 END),0)     
         ,Showlogo       = ISNULL(MAX(CASE WHEN Code = 'SHOWLOGO'  THEN 1 ELSE 0 END),0)         
         ,ShowLottable06 = ISNULL(MAX(CASE WHEN Code = 'ShowLottable06'  THEN 1 ELSE 0 END),0)   
         ,ShowLottable0708 = ISNULL(MAX(CASE WHEN Code = 'ShowLottable0708'  THEN 1 ELSE 0 END),0)   
   INTO #TMP_RPTCFG  
   FROM CODELKUP WITH (NOLOCK)  
   WHERE ListName = 'REPORTCFG'  
   AND Long      = 'RPT_ASN_GINCTN_001'  
   AND (Short IS NULL OR Short <> 'N')  
   GROUP BY Storerkey  
  
   INSERT INTO #InwardNotesCtn02  
   (   Company,        ReceiptKey,     CarrierReference,   StorerKey,  
       CarrierName,    AddWho,         ReceiptDate,  
       Sku,            Lottable02,     DESCR,              Lottable04,  
       UOM,            QtyExp,         QtyRec,  
       STDCUBE,        RECNOTES,       CarrierAddress1,  
       POkey,          CaseCnt,        Lottable03,  
       RHSignatory,    Userdefine01,   Facility,           Externreceiptkey,  
       lottable01,     Containerkey,   conditiondesc,      containertype,  
       Signatory,      SortByLOTT02,   ShowLot15,          Lottable15, SortByLOTT01, showlogo, ShowLottable06, Lottable06,   
       ConditionCode,showgin,ShowLottable0708,Lottable07,Lottable08)        --CS01  
   SELECT STORER.Company,  
          RECEIPT.ReceiptKey,  
          ISNULL(RECEIPT.CarrierReference,''),  
          RECEIPT.StorerKey,  
          ISNULL(RECEIPT.CarrierName,''),  
          RECEIPT.AddWho,  
          RECEIPT.ReceiptDate,  
          RECEIPTDETAIL.Sku,  
          ISNULL(RECEIPTDETAIL.Lottable02,''),  
          SKU.DESCR,  
          RECEIPTDETAIL.Lottable04,  
          RECEIPTDETAIL.UOM,  
          SUM(RECEIPTDETAIL.QtyExpected) AS QtyExp,  
          SUM(RECEIPTDETAIL.QtyReceived) AS QtyRec,  
          SKU.STDCUBE,  
          ISNULL(CONVERT(NVARCHAR(60), RECEIPT.NOTES),'') AS RECNOTES ,  
          ISNULL(RECEIPT.CarrierAddress1,''),  
          ISNULL(RECEIPT.POkey,''),  
          PACK.CaseCnt,  
          ISNULL(RECEIPTDETAIL.Lottable03,''),  
          ISNULL(RECEIPT.Signatory,'') AS RHSignatory,  
          ISNULL(RECEIPT.Userdefine01,''),  
          RECEIPT.Facility,  
          RECEIPTDETAIL.Externreceiptkey,  
          ISNULL(RECEIPTDETAIL.lottable01,''),  
          ISNULL(RECEIPT.Containerkey,''),  
          (SELECT ISNULL(CODELKUP.Description,'') FROM CODELKUP (nolock) WHERE CODELKUP.listname='ASNREASON' AND CODELKUP.code = RECEIPTDETAIL.Conditioncode) AS conditiondesc,  
          ISNULL((SELECT ISNULL(CODELKUP.Description,'') FROM CODELKUP (nolock) WHERE CODELKUP.listname='CONTAINERT' AND CODELKUP.code = RECEIPT.ContainerType),'') AS containertype  
         ,Signatory = CASE WHEN ISNULL(RTRIM(ST.Contact2),'') = '' THEN 'Maersk' ELSE ST.Contact2 END  
         ,SortByLOTT02 = ISNULL(#TMP_RPTCFG.SortByLOTT02,0)  
         ,ShowLot15 = ISNULL(#TMP_RPTCFG.ShowLot15,0)                              
         ,RECEIPTDETAIL.Lottable15                                                 
         ,SortByLOTT01 = ISNULL(#TMP_RPTCFG.SortByLOTT01,0)                         
         ,showlogo = ISNULL(#TMP_RPTCFG.Showlogo,0)                                 
         ,ShowLottable06 = ISNULL(#TMP_RPTCFG.ShowLottable06,0)                     
         ,RECEIPTDETAIL.Lottable06                                                  
         ,CASE WHEN RECEIPTDETAIL.ConditionCode = 'D08' THEN 'QI' ELSE 'OK' END AS GIN  
         ,ISNULL(c1.short,'') AS showgin 
         ,ShowLottable0708 = ISNULL(#TMP_RPTCFG.ShowLottable0708,0)       --CS01
         ,ISNULL(RECEIPTDETAIL.lottable07,''),ISNULL(RECEIPTDETAIL.lottable08,'')    --CS01
   FROM RECEIPT    WITH (nolock)  
   JOIN RECEIPTDETAIL  WITH (nolock)  ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )  
   JOIN STORER    WITH (nolock)  ON ( RECEIPTDETAIL.StorerKey = STORER.StorerKey )  
   JOIN SKU     WITH (nolock)  ON ( RECEIPTDETAIL.StorerKey = SKU.StorerKey ) and  
                     ( RECEIPTDETAIL.Sku = SKU.Sku )  
   JOIN PACK     WITH (nolock)  ON ( SKU.PackKey = PACK.PackKey )  
   LEFT JOIN STORER ST WITH (NOLOCK)  ON ( ST.Storerkey = 'IDS' )  
   LEFT JOIN #TMP_RPTCFG WITH (NOLOCK) ON #TMP_RPTCFG.storerkey = RECEIPT.StorerKey 
   LEFT JOIN codelkup c1 WITH (NOLOCK) ON c1.LISTNAME = 'reportcfg' AND c1.Storerkey = RECEIPT.StorerKey AND c1.long = 'RPT_ASN_GINCTN_001' AND c1.code = 'showgin'
   WHERE (RECEIPT.ReceiptKey = @c_Receiptkey ) 
   GROUP BY STORER.Company,  
            RECEIPT.ReceiptKey,  
            RECEIPT.CarrierReference,  
            RECEIPT.StorerKey,  
            RECEIPT.CarrierName,  
            RECEIPT.AddWho,  
            RECEIPT.ReceiptDate,  
            RECEIPTDETAIL.Sku,  
            RECEIPTDETAIL.Lottable02,  
            SKU.DESCR,  
            RECEIPTDETAIL.Lottable04,  
            RECEIPTDETAIL.UOM,  
            SKU.STDCUBE,  
            CONVERT(NVARCHAR(60), RECEIPT.NOTES) ,  
            RECEIPT.CarrierAddress1,  
            RECEIPT.POkey,  
            PACK.CaseCnt,  
            RECEIPTDETAIL.Lottable03,  
            RECEIPT.Signatory,  
            RECEIPT.Userdefine01,  
            RECEIPT.Facility,  
            RECEIPTDETAIL.Externreceiptkey,  
            RECEIPTDETAIL.lottable01,  
            RECEIPT.Containerkey,  
            RECEIPTDETAIL.Conditioncode,  
            RECEIPT.ContainerType,  
            CASE WHEN ISNULL(RTRIM(ST.Contact2),'') = '' THEN 'Maersk' ELSE ST.Contact2 END,  
            #TMP_RPTCFG.SortByLOTT02,ISNULL(#TMP_RPTCFG.ShowLot15,0), RECEIPTDETAIL.Lottable15          
           ,ISNULL(#TMP_RPTCFG.SortByLOTT01,0)                        
           ,ISNULL(#TMP_RPTCFG.Showlogo,0)                          
           ,ISNULL(#TMP_RPTCFG.ShowLottable06,0)                     
           ,RECEIPTDETAIL.Lottable06                                  
           ,CASE WHEN RECEIPTDETAIL.ConditionCode = 'D08' THEN 'QI' ELSE 'OK' END  
           ,ISNULL(c1.short,'') 
           ,ISNULL(#TMP_RPTCFG.ShowLottable0708,0)       --CS01 
           ,ISNULL(RECEIPTDETAIL.lottable07,''),ISNULL(RECEIPTDETAIL.lottable08,'')    --CS01
   GOTO SUCCESS  
FAILURE:  
   DELETE FROM #InwardNotesCtn02  
SUCCESS:  
   SELECT * FROM #InwardNotesCtn02  
  
   ORDER BY CASE WHEN SortByLOTT02 = 1 THEN lottable02 ELSE '' END  
         ,  CASE WHEN SortByLOTT01 = 1 THEN lottable01 ELSE '' END               
         ,  ReceiptKey  
         ,  Sku  
         ,  CASE WHEN SortByLOTT02 = 1 THEN '' ELSE lottable02 END  
  
   IF OBJECT_ID('tempdb..#InwardNotesCtn02') IS NOT NULL
      DROP TABLE #InwardNotesCtn02
END  

GO