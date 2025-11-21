SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/  
/* Stored Procedure: isp_RecvCheckList_rpt                               */  
/* Creation Date: 2018-03-26                                             */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-4207 -HM JP - Receiving Checking Lists - report printing */  
/*                                                                       */  
/* Called By: r_receipt_checklist_rpt                                    */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/* 2018-Apr-18  CSCHONG 1.0   WMS-4207 revised field logic (CS01)        */  
/* 2018-Jun-13  CSCHONG 1.1   WMS-4207 add new field (CS02)              */  
/* 2018-Oct-09  CSCHONG 1.2   WMS-6501 revised field logic (CS03)        */  
/* 2019-Nov-29  Grick   1.3   INC0952954 - Cater for HMCOS  (G01)        */  
/* 2020-Aug-10  WLChooi 1.4   WMS-14520 - Modify input parameter for     */  
/*                            range printing (WL01)                      */  
/* 2020-Aug-21  WLChooi 1.5   Fix Qty issue (WL02)                       */  
/*************************************************************************/  
  
CREATE PROC [dbo].[isp_RecvCheckList_rpt]   
         (  --WL01 START  
            --@c_Receiptkey    NVARCHAR(10)  
            @c_Storerkey         NVARCHAR(15)  
          , @c_ReceiptkeyStart   NVARCHAR(10)  
          , @c_ReceiptkeyEnd     NVARCHAR(10)  
            --WL01 END  
         )  
           
           
           
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   --WL01 START  
   -- DECLARE @c_storerkey  NVARCHAR(10)  
   --        ,@n_NoOfLine   INT  
   DECLARE @n_NoOfLine     INT,  
           @c_Receiptkey   NVARCHAR(10)  
   --WL01 END  
     
   CREATE TABLE #TEMPRCVCHKLIST (  
   [LineNo]      NVARCHAR(3),  
   HMOrder       NVARCHAR(30),  
   CartonNo      NVARCHAR(30),  
   SSM           NVARCHAR(5),  
   SKU           NVARCHAR(20),  
   SDESCR        NVARCHAR(200),  
   nd_qty        INT,  
   QC            NVARCHAR(10),  
   qtyexp        INT,  
   qtyreceived   INT,  
   qtydiff       INT,  
   remark        NVARCHAR(200),  
   reckey        NVARCHAR(20),  
   signatory     NVARCHAR(20),  
   CNTSCTN       INT,  
   CNTSMCTN      INT,  
   SQty          INT,  
   SMQty         INT,  
   RecLineNo     NVARCHAR(10),           --CS01  
   ReceiptQtyExp INT NULL   --WL01  
   --B8            NVARCHAR(200) NULL,  
   --B9            NVARCHAR(200) NULL,  
   --B10           NVARCHAR(200) NULL,  
   --B11           NVARCHAR(200),  
   --B12           NVARCHAR(200),  
   --B13           NVARCHAR(200),  
   --B14           NVARCHAR(200),  
   --B15           NVARCHAR(200),  
   --B16           NVARCHAR(200),  
   --B17           NVARCHAR(200),  
   --B18           NVARCHAR(200),  
   --B19           NVARCHAR(200),  
   --F1            NVARCHAR(200),  
   --F2            NVARCHAR(200),  
   --F3            NVARCHAR(200),  
   --F4            NVARCHAR(200)             
     
   )  
     
   SET @n_NoOfLine = 20  
    
   DECLARE @c_Reckey            NVARCHAR(20),  
           @c_signatory         NVARCHAR(20),  
           @n_CntCnts           INT,  
           @n_cntcntsm          INT,  
           @n_sqty              INT,  
           @n_Smqty             INT  
     
   --WL01 START  
   -- SELECT TOP 1 @c_storerkey = REC.Storerkey  
   -- FROM RECEIPT REC (NOLOCK)  
   -- WHERE Receiptkey = @c_receiptkey  
  
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Receiptkey  
   FROM RECEIPT (NOLOCK)  
   WHERE RECEIPT.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd  
   AND RECEIPT.Storerkey = @c_Storerkey  
  
   OPEN CUR_LOOP   
  
   FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey  
  
   WHILE @@FETCH_STATUS <> -1     
   BEGIN   --WL01 END  
      INSERT INTO #TEMPRCVCHKLIST  
      (  
         [LineNo],  
         HMOrder,  
         CartonNo,  
         SSM,  
         SKU,  
         SDESCR,  
         nd_qty,  
         QC,  
         qtyexp,  
         qtyreceived,  
         qtydiff,  
         remark,  
         reckey,  
         signatory,  
         CNTSCTN,  
         CNTSMCTN,  
         SQty,  
         SMQty,  
         RecLineNo                    --(CS01)  
      )  
     
      SELECT   
       RIGHT( '000' + CAST ( ( RANK() OVER (ORDER BY PoHD.OtherReference ,  RecDT.SKU , RecDT.UserDefine01) )  AS NVARCHAR) , 3) [LineNo],   
       PoDT.Lottable12 [HMOrder] ,--PoHD.OtherReference [HMOrder] ,   --CS03  
       PoDT.UserDefine01 [CartonNo] ,   
       CASE WHEN IsNull ( ( SELECT COUNT(1)   
                              FROM PODetail(NOLOCK) PoDT1   
           WHERE PoDT.StorerKey = PoDT1.StorerKey   
             AND PoDT.UserDefine01 = PoDT1.UserDefine01   
             AND PoDT.Pokey = PoDT1.Pokey  
            ) , 0  
          ) > 1 Then 'SM'  
            ELSE 'S'  
       END  [SSM] ,  
       SUBSTRING(RecDT.SKU,1,7) + '-' + SUBSTRING(RecDT.SKU,8,3) + '-' + SUBSTRING(RecDT.SKU , 11 , 3 ) [SKU] , -- RecDT.SKU [SKU1] ,   
       PoDT.SKUDescription [Sdescr],   
       --RANK() OVER ( PARTITION BY SUBSTRING(RecDT.SKU,1,10) ORDER BY SUBSTRING(RecDT.SKU , 11 , 3 ) ) [QC_Rank] ,   
       ISNULL(CONVERT(INT,CkUP.Short),'') [ND_QTY] , --G01 --NDQty.TotalOrderedQty ,  
       Case When RANK() OVER ( PARTITION BY SUBSTRING(RecDT.SKU,1,10) ORDER BY SUBSTRING(RecDT.SKU , 12 , 3 ), RecDT.UserDefine01 ) = '1' Then 'QC'  --(CS01)  
            Else ''   
       End [QC] ,   
       RecDT.QtyExpected [QtyExp],   
       0 [QtyReceived] , 0 [QtyDiff] , 0 [Remark],  
       RECHD.ReceiptKey AS RecKey,  
       RECHD.Signatory AS Signatory,  
       0,0,0,0  
      , recdt.ReceiptLineNumber                         --(CS01)  
       --, CASE WHEN ISNULL(C1.Code,'') = '00020' THEN C1.[Description] ELSE '' END AS F1  
       --, CASE WHEN ISNULL(C1.Code,'') = '00021' THEN C1.[Description] ELSE '' END AS F2  
       --, CASE WHEN ISNULL(C1.Code,'') = '00022' THEN C1.[Description] ELSE '' END AS F3  
       --, CASE WHEN ISNULL(C1.Code,'') = '00023' THEN C1.[Description] ELSE '' END AS F4  
      FROM Receipt (NOLOCK) RecHD  
      JOIN ReceiptDetail (NOLOCK) RecDT  
       ON RecHD.StorerKey = RecDT.StorerKey  
      AND RecHD.ReceiptKey = RecDT.ReceiptKey  
      JOIN PODetail (NOLOCK) PoDT  
       ON RecDT.StorerKey = @c_storerkey  
      AND RecDT.POKey = PoDT.POKey  
      AND RecDT.POLineNumber = PoDT.POLineNumber  
      JOIN PO (NOLOCK) PoHD  
       ON PoDT.StorerKey = PoHD.StorerKey  
      AND PoDT.PoKey = PoHD.Pokey  
      JOIN ( SELECT PoDT2.PoKey , PoDT2.StorerKey , Sum(PoDT2.QtyOrdered) [TotalOrderedQty]  
             FROM PODETAIL(NOLOCK) PoDT2  
             WHERE PoDT2.StorerKey = @c_storerkey --G01  
             AND PoKey in (SELECT POKEY   
                           FROM ReceiptDetail(NOLOCK) RecDT2   
                           WHERE ReceiptKey = @c_Receiptkey  
                           AND StorerKey = @c_storerkey  
                          )  
             GROUP BY PoDT2.PoKey , PoDT2.StorerKey  
          ) NDQty  
       ON PoDT.StorerKey = NDQty.StorerKey  
      AND PoDt.POKey = NDQty.POKey  
      LEFT JOIN CODELKUP(nolock) CkUP  
       ON CkUP.LISTNAME = 'HMNDQTY'  
      AND CkUp.StorerKey = LEFT(NDQty.StorerKey,2)  --G01  
      AND NDQty.TotalOrderedQty Between CkUP.UDF01 AND CkUP.UDF02  
      --LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME='HMIBRCPT' AND C1.Storerkey=NDQty.StorerKey  
      WHERE RecHD.ReceiptKey = @c_Receiptkey  
      AND RecHD.StorerKey = @c_storerkey  
      ORDER BY PoHD.OtherReference ,    
               SUBSTRING(RecDT.SKU,1,7) + '-' + SUBSTRING(RecDT.SKU,8,3) + '-' + SUBSTRING(RecDT.SKU , 11 , 3 ) ,   
               PoDT.UserDefine01  
  
      --WL01 START  
      FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey  
   END  
   --WL01 END  
               
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT t.reckey,t.signatory     
   FROM #TEMPRCVCHKLIST AS t  
   --WHERE t.reckey = @c_Receiptkey   --WL01  
    
   OPEN CUR_RESULT     
       
   FETCH NEXT FROM CUR_RESULT INTO @c_Reckey,@c_signatory      
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN           
      SET @n_CntCnts = 1  
      SET @n_cntcntsm = 1  
      SET @n_sqty = 1  
      SET @n_Smqty = 1  
        
      SELECT @n_CntCnts = COUNT(DISTINCT CartonNo)  
      FROM #TEMPRCVCHKLIST AS t   
      WHERE reckey = @c_Reckey   
      AND signatory = @c_signatory  
      AND ssm = 'S'  
        
      SELECT @n_CntCntsm = COUNT(DISTINCT CartonNo)  
      FROM #TEMPRCVCHKLIST AS t   
      WHERE reckey = @c_Reckey   
      AND signatory = @c_signatory  
      AND ssm = 'SM'  
        
      SELECT @n_sqty = SUM(t.qtyexp)  
      FROM #TEMPRCVCHKLIST AS t   
      WHERE reckey = @c_Reckey   
      AND signatory = @c_signatory  
      AND ssm = 'S'  
        
      SELECT @n_smqty = SUM(t.qtyexp)  
      FROM #TEMPRCVCHKLIST AS t   
      WHERE reckey = @c_Reckey   
      AND signatory = @c_signatory  
      AND ssm = 'SM'  
        
      UPDATE #TEMPRCVCHKLIST  
      SET  
         CNTSCTN = ISNULL(@n_CntCnts,0),  
         CNTSMCTN = ISNULL(@n_CntCntsm,0),  
         SQty = ISNULL(@n_sqty,0),  
         SMQty = ISNULL(@n_smqty,0)  
      WHERE reckey = @c_Reckey   
      AND signatory = @c_signatory    
        
   FETCH NEXT FROM CUR_RESULT INTO  @c_Reckey,@c_signatory     
   END     
  
   --WL02 START  
   DECLARE @n_Qty INT = 0  
  
   DECLARE CUR_Qty CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT t.reckey     
   FROM #TEMPRCVCHKLIST AS t  
    
   OPEN CUR_Qty     
       
   FETCH NEXT FROM CUR_Qty INTO @c_Reckey  
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN           
      SELECT @n_Qty = SUM(qtyexp)  
      FROM #TEMPRCVCHKLIST  
      WHERE reckey = @c_Reckey  
  
      UPDATE #TEMPRCVCHKLIST  
      SET ReceiptQtyExp = @n_Qty  
      WHERE reckey = @c_Reckey  
        
      FETCH NEXT FROM CUR_Qty INTO @c_Reckey     
   END     
   --WL02 END  
  
   SELECT t.*  
         ,ISNULL(MAX(CASE WHEN C.Code = '00008' THEN RTRIM(C.Description) ELSE '' END),'') AS B8  
         ,ISNULL(MAX(CASE WHEN C.Code = '00009' THEN RTRIM(C.Description) ELSE '' END),'') AS B9  
         ,ISNULL(MAX(CASE WHEN C.Code = '00010' THEN RTRIM(C.Description) ELSE '' END),'') AS B10  
         ,ISNULL(MAX(CASE WHEN C.Code = '00011' THEN RTRIM(C.Description) ELSE '' END),'') AS B11  
         ,ISNULL(MAX(CASE WHEN C.Code = '00012' THEN RTRIM(C.Description) ELSE '' END),'') AS B12  
         ,ISNULL(MAX(CASE WHEN C.Code = '00013' THEN RTRIM(C.Description) ELSE '' END),'') AS B13  
         ,ISNULL(MAX(CASE WHEN C.Code = '00014' THEN RTRIM(C.Description) ELSE '' END),'') AS B14  
         ,ISNULL(MAX(CASE WHEN C.Code = '00015' THEN RTRIM(C.Description) ELSE '' END),'') AS B15  
         ,ISNULL(MAX(CASE WHEN C.Code = '00016' THEN RTRIM(C.Description) ELSE '' END),'') AS B16  
         ,ISNULL(MAX(CASE WHEN C.Code = '00017' THEN RTRIM(C.Description) ELSE '' END),'') AS B17  
         ,ISNULL(MAX(CASE WHEN C.Code = '00018' THEN RTRIM(C.Description) ELSE '' END),'') AS B18  
         ,ISNULL(MAX(CASE WHEN C.Code = '00019' THEN RTRIM(C.Description) ELSE '' END),'') AS B19  
         ,ISNULL(MAX(CASE WHEN C.Code = '00020' THEN RTRIM(C.Description) ELSE '' END),'') AS F1  
         ,ISNULL(MAX(CASE WHEN C.Code = '00021' THEN RTRIM(C.Description) ELSE '' END),'') AS F2  
         ,ISNULL(MAX(CASE WHEN C.Code = '00022' THEN RTRIM(C.Description) ELSE '' END),'') AS F3  
         ,ISNULL(MAX(CASE WHEN C.Code = '00023' THEN RTRIM(C.Description) ELSE '' END),'') AS F4  
         ,ISNULL(MAX(CASE WHEN C.Code = '00001' THEN RTRIM(C.Description) ELSE '' END),'') AS A1  
         ,ISNULL(MAX(CASE WHEN C.Code = '00002' THEN RTRIM(C.Description) ELSE '' END),'') AS A2  
         ,ISNULL(MAX(CASE WHEN C.Code = '00003' THEN RTRIM(C.Description) ELSE '' END),'') AS A3  
         ,ISNULL(MAX(CASE WHEN C.Code = '00004' THEN RTRIM(C.Description) ELSE '' END),'') AS A4  
         ,ISNULL(MAX(CASE WHEN C.Code = '00005' THEN RTRIM(C.Description) ELSE '' END),'') AS A5  
         ,ISNULL(MAX(CASE WHEN C.Code = '00006' THEN RTRIM(C.Description) ELSE '' END),'') AS A6  
         ,ISNULL(MAX(CASE WHEN C.Code = '00007' THEN RTRIM(C.Description) ELSE '' END),'') AS A7  
         ,((Row_Number() OVER (PARTITION BY reckey ORDER BY reckey,[LineNo] Asc)-1)/@n_NoOfLine)+1 AS Recgrp  
         ,ISNULL(MAX(CASE WHEN C.Code = '00024' THEN RTRIM(C.Description) ELSE '' END),'') AS B24  
   FROM #TEMPRCVCHKLIST AS t  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='HMIBRCPT' AND C.Storerkey= LEFT(@c_storerkey,2)--G01  
   GROUP BY   [LineNo],  
      HMOrder,  
      CartonNo,  
      SSM,  
      SKU,  
      SDESCR,  
      nd_qty,  
      QC,  
      qtyexp,  
      qtyreceived,  
      qtydiff,  
      remark,  
      reckey,  
      signatory,  
      CNTSCTN,  
      CNTSMCTN,  
      SQty,  
      SMQty  
     ,RecLineNo             --(CS01)  
     ,ReceiptQtyExp   --WL02  
   ORDER BY t.reckey, t.[LineNo]   --WL01  
     
QUIT_SP:  
   --WL02 START  
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)  
   BEGIN  
      CLOSE CUR_LOOP  
      DEALLOCATE CUR_LOOP     
   END  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_RESULT') IN (0 , 1)  
   BEGIN  
      CLOSE CUR_RESULT  
      DEALLOCATE CUR_RESULT     
   END  
  
   IF CURSOR_STATUS('LOCAL', 'CUR_Qty') IN (0 , 1)  
   BEGIN  
      CLOSE CUR_Qty  
      DEALLOCATE CUR_Qty     
   END  
  
   --WL02 END  
      
END  
  

GO