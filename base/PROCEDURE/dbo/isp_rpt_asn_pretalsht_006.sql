SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_ASN_PRETALSHT_006                          */        
/* Creation Date: 2-AUG-2022                                            */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: Convert to Logi Report - r_receipt_pre_tallysheet10  (TH)   */      
/*                                                                      */        
/* Called By: RPT_RPT_ASN_PRETALSHT_006										   */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 2-AUG-2022  WZPang   1.0  DevOps Combine Script                      */     
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_ASN_PRETALSHT_006] (
      @c_receiptkey      NVARCHAR(10)        
)        
 AS        
 BEGIN        
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF         
        
      DECLARE @n_continue INT = 1, @n_err INT = 0, @c_errmsg NVARCHAR(255) = '', @b_Success INT = 1  
           , @n_StartTCnt INT = @@TRANCOUNT, @c_GetReceiptKey NVARCHAR(10), @c_GetUserDefine03 NVARCHAR(30)  
           , @n_PalletPosCnt        INT = 0  
           --, @c_Receiptkey          NVARCHAR(10)  
           , @c_SKU                 NVARCHAR(30)  
           , @c_ItemClass           NVARCHAR(20)  
           , @n_Qty                 INT = 0  
           , @c_PalletPos           NVARCHAR(20)  
           , @n_PrevPalletPosCnt    INT = 0  
           , @c_PrevItemClass       NVARCHAR(20)  
           , @n_CountUCC            INT = 0  
           , @n_cntplt              INT = 0  
           , @c_GetRecKey           NVARCHAR(20)  
           , @c_GetPLTPosition      NVARCHAR(10)  
           , @c_UCCNo               NVARCHAR(20)  
           , @c_GetSKU              NVARCHAR(20)  
           , @n_GetUccNoCtn         INT  
           , @n_MaxUccCtn           INT  
           , @n_CtnSku              INT  
           , @n_ctnuccsku           INT  
           , @c_T2Sku               NVARCHAR(20)
           , @n_Cnt                 INT
           , @c_Qty                 NVARCHAR(20)
           , @c_Storerkey           NVARCHAR(20)
           , @c_PalletPosition      NVARCHAR(5)
  
  
   CREATE TABLE #ITEMCLASS(  
   RECEIPTKEY         NVARCHAR(10),  
   SKU                NVARCHAR(30),  
   Qty                INT,  
   ItemClass          NVARCHAR(20),  
   UCCNo              NVARCHAR(20),  
   PalletPosition     NVARCHAR(10),  
   CountPallet        INT  ,  
   UCCUDF08           NVARCHAR(30),  
   Indicator          NVARCHAR(5),  
   TTLQTY             INT,  
   UCCNoCnt           INT DEFAULT(0),
   Storerkey          NVARCHAR(20))  
  
   INSERT INTO #ITEMCLASS  
   SELECT RECEIPT.RECEIPTKEY,  
          RECEIPTDETAIL.SKU,  
          CASE WHEN ISNULL(UCC.Qty,0) = 0 THEN SUM(RECEIPTDETAIL.QtyExpected) ELSE ISNULL(UCC.Qty,0) END AS Qty,  
          SKU.style,  
          ISNULL(UCC.UCCNo,'') AS UCCNo,  
          PalletPosition = CASE WHEN UCC.Userdefined06 = '1' AND (UCC.Userdefined08 IN ('HV') OR UCC.Userdefined09 = '1')  THEN 'QC-F'  
                          WHEN (UCC.Userdefined08 IN ('HV') OR UCC.Userdefined09 = '1')  THEN 'QC'  
                                WHEN UCC.Userdefined06 = '1' AND (UCC.Userdefined08 ='BL' AND UCC.Userdefined09 = '')  THEN 'BL-F'  
                                WHEN UCC.Userdefined08 ='BL' AND UCC.Userdefined09 = '' THEN 'BL'  
                                WHEN UCC.Userdefined06 = '1' AND UCC.Userdefined08 ='' AND UCC.Userdefined09 = '' THEN 'F'  
                                WHEN UCC.Userdefined06 = '' AND UCC.Userdefined07 = '1' AND UCC.Userdefined08 ='' AND UCC.Userdefined09 = '' THEN 'M'  
                                --ELSE 'N' + CAST(COUNT(DISTINCT SKU.style) AS NVARCHAR(10)) END,  
                                ELSE '' END,--+ cast( (ROW_NUMBER() over (partition by SKU.style order by SKU.style)) as varchar(5)) END,  
          CountPallet = 0,--COUNT(DISTINCT SKU.style) + 6,  
          UCCUDF08 = CASE WHEN ISNULL(UCC.Userdefined08,'') <> '' THEN UCC.Userdefined08 ELSE '' END,  
          Indicator = CASE WHEN SKU.Length = '0' OR SKU.Width = '0' OR SKU.Height = '0' THEN '*' ELSE '' END,0 AS qty,0 AS UCCNoCnt,  
          RECEIPT.Storerkey
   FROM RECEIPT (NOLOCK)  
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
   JOIN SKU (NOLOCK) ON RECEIPTDETAIL.SKU = SKU.SKU AND RECEIPT.STORERKEY = SKU.STORERKEY  
   LEFT JOIN UCC (NOLOCK) ON UCC.UCCNo = RECEIPTDETAIL.UserDefine01  AND UCC.Storerkey = RECEIPT.Storerkey AND UCC.SKU = RECEIPTDETAIL.SKU  
                             AND ReceiptDetail.ExternReceiptkey= UCC.Externkey  
   WHERE ( RECEIPT.ReceiptKey = @c_Receiptkey )
   GROUP BY RECEIPT.RECEIPTKEY, RECEIPTDETAIL.SKU, ISNULL(UCC.Qty,0), ISNULL(UCC.UCCNo,''),  
            UCC.Userdefined06,  
            UCC.Userdefined07,  
            UCC.Userdefined08, UCC.Userdefined09 ,SKU.style, ISNULL(SKU.SUSR1,0),SKU.Length ,  SKU.Width ,  SKU.Height, RECEIPT.StorerKey  
  
--SELECT * FROM #ITEMCLASS  
  
 DECLARE cur_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT  t.SKU
         , t.RECEIPTKEY
         , t.Storerkey
   FROM #ITEMCLASS t  
   GROUP BY t.SKU, t.RECEIPTKEY, t.Storerkey
   ORDER BY t.SKU
     
   OPEN cur_Loop  
  
   FETCH NEXT FROM cur_Loop INTO  @c_SKU  
                                , @c_Receiptkey
                                , @c_Storerkey
  
   WHILE @@FETCH_STATUS <> - 1  
   BEGIN  
      SET @n_Cnt = 0
      SET @c_Qty = ''

      SELECT @n_Cnt = COUNT(1)
            ,@c_qty = ISNULL(SUM(Qty),'0')
      FROM LOTxLOCxID(NOLOCK)
      WHERE SKU = @c_SKU
      AND Storerkey = @c_Storerkey
      
      IF @n_Cnt = 0 OR @c_qty = 0 
      BEGIN
         SET @c_PalletPosition = 'F'
      END
      ELSE
      BEGIN
            SET @c_PalletPosition = 'N'
      END
      UPDATE #ITEMCLASS  
      SET PalletPosition = @c_PalletPosition
      WHERE RECEIPTKEY = @c_Receiptkey  
      AND SKU = @c_SKU  
  
      SET @c_PrevItemClass = @c_ItemClass  
  
  
      FETCH NEXT FROM cur_Loop INTO  @c_SKU  
                                    ,@c_Receiptkey
                                    ,@c_Storerkey
   END  
  
  SELECT DISTINCT receiptkey AS receiptkey,PalletPosition AS PalletPosition,uccno AS uccno,MAX(sku) AS sku,COUNT(DISTINCT sku) AS ctnuccno  
  INTO #ITEMCLASS1  
  FROM #ITEMCLASS  
--WHERE PalletPosition<>'M'  
  GROUP BY receiptkey,PalletPosition,uccno  
  
  SELECT DISTINCT receiptkey AS receiptkey,PalletPosition AS PalletPosition,sku AS sku,COUNT(uccno) AS ctnuccno  
  INTO #ITEMCLASS2  
  FROM #ITEMCLASS  
--WHERE PalletPosition<>'M'  
 GROUP BY receiptkey,PalletPosition,sku  
  
  
   DECLARE cur_GetCntPltLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT DISTINCT T1.receiptkey,MAX(T1.ctnuccno) ,t1.PalletPosition ,MAX(T2.ctnuccno),t2.sku AS sku  
    FROM #ITEMCLASS1 T1  
    JOIN #ITEMCLASS2 T2 ON t2.receiptkey = t1.receiptkey AND T2.PalletPosition=T1.PalletPosition AND T2.sku=T1.sku  
    GROUP BY t1.Receiptkey,  
          t1.PalletPosition,t2.sku  
   ORDER BY t1.RECEIPTKEY, t1.PalletPosition,t2.sku  
  
   OPEN cur_GetCntPltLoop  
  
   FETCH NEXT FROM cur_GetCntPltLoop INTO   @c_GetRecKey,@n_MaxUccCtn  
                                       --   , @c_UCCNo  
                                          , @c_GetPLTPosition  
                                          , @n_ctnuccsku  
                                          , @c_T2Sku  
   WHILE @@FETCH_STATUS <> - 1  
   BEGIN  
    SET @c_GetSKU = ''  
    SET @n_GetUccNoCtn = 1  
    SET @n_CtnSku  = 1  
  
    IF @n_MaxUccCtn = 1  
    BEGIN  
      SET @n_GetUccNoCtn = 1  
      SET @c_GetSKU = ''  
  
     IF @n_ctnuccsku > @n_MaxUccCtn  
     BEGIN  
      SET @n_GetUccNoCtn = @n_ctnuccsku  
  
     END  
  
       UPDATE #ITEMCLASS  
       SET UCCNoCnt = @n_GetUccNoCtn  
       WHERE Receiptkey = @c_GetRecKey  
       AND PalletPosition = @c_GetPLTPosition  
       ANd sku = CASE WHEN ISNULL(@c_T2Sku,'') <> '' THEN @c_T2Sku ELSE sku end  
    END  
    ELSE  
    BEGIN  
  
       SELECT @n_GetUccNoCtn = COUNT(1)  
       FROM #ITEMCLASS1  
       WHERE PalletPosition = @c_GetPLTPosition  
       AND receiptkey = @c_GetRecKey  
  
       SELECT @c_GetSKU = MAX(SKU)  
       FROM #ITEMCLASS  
       WHERE PalletPosition = @c_GetPLTPosition  
       AND receiptkey = @c_GetRecKey  
  
       UPDATE #ITEMCLASS  
       SET UCCNoCnt = @n_GetUccNoCtn  
       WHERE Receiptkey = @c_GetRecKey  
       AND PalletPosition = @c_GetPLTPosition  
       AND sku = CASE WHEN LEFT(@c_GetPLTPosition,1) = 'N' THEN @c_T2Sku ELSE @c_GetSKU END  
  
    END  
  
  
    FETCH NEXT FROM cur_GetCntPltLoop INTO   @c_GetRecKey,@n_MaxUccCtn  
                                       --   , @c_UCCNo  
                                           , @c_GetPLTPosition  
                                           , @n_ctnuccsku  
                                           , @c_T2Sku  
   END  
  
   SELECT RECEIPT.ReceiptKey,  
          ''  AS ExternPokey,
          --(t.Sku) + (t.Indicator)AS SKU,  
          (t.Sku) AS SKU, 
          PRINCIPAL = SKU.SUSR3,  
          PRINDESC = CODELKUP.DESCRIPTION,  
          SKU.DESCR,  
          RECEIPTDETAIL.UOM,  
          STORER.Company,  
          RECEIPT.ReceiptDate,  
          RECEIPTDETAIL.PackKey,  
          SKU.SUSR3,  
         (SELECT SUM(Qty) FROM #ITEMCLASS WHERE #ITEMCLASS.RECEIPTKEY = RECEIPT.ReceiptKey  
                                             AND #ITEMCLASS.SKU = t.SKU  
                                             AND #ITEMCLASS.PalletPosition = t.Palletposition ) AS QtyExpected,  
          --ELSE (t.ttlQty) END AS QtyExpected,  
          RECEIPT.WarehouseReference,  
          PACK.CaseCnt,  
          PACK.Pallet,  
          PACK.PackUOM3,  
          SUM(RECEIPTDETAIL.FreeGoodQtyExpected) AS FreeGoodQtyExpected,  
          SUSER_NAME() AS Compute_0018,  
          PACK.PackUOM1,  
          PACK.PackUOM2,  
          PACK.PackUOM4,  
          Pack.Innerpack,  
          RECEIPT.ExternReceiptkey,  
          '' AS Lottable01,  
          '' AS Lottable02,  
          '' AS Lottable12,  
          RECEIPTDETAIL.Lottable04,  
          (t.ItemClass),  
          (t.PalletPosition),  
          ISNULL(t.UCCNoCnt,0) AS UCCNoCnt,  
           (SELECT count(distinct itemclass) + 6 FROM #ITEMCLASS WHERE #ITEMCLASS.RECEIPTKEY = RECEIPT.ReceiptKey) AS CountPallet,--t.CountPallet,  
          (SELECT TOP 1 RD.ToLoc FROM RECEIPTDETAIL RD (NOLOCK) WHERE RD.RECEIPTKEY = RECEIPT.RECEIPTKEY) AS ToLoc,  
          (t.UCCUDF08),  
          CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Hideskubarcode,  
          MAX(PO.Userdefine02) AS poudf02,         
          PO.SellersReference,     
          ISNULL(CLR2.SHORT,'') AS SHOWFIELD   
    FROM RECEIPT (NOLOCK)  
    JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey  
    JOIN SKU (NOLOCK) ON SKU.StorerKey = RECEIPTDETAIL.StorerKey AND SKU.Sku = RECEIPTDETAIL.Sku  
    JOIN STORER (NOLOCK) ON RECEIPT.Storerkey = STORER.Storerkey  
    JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey  
    JOIN PO (NOLOCK) ON PO.POKey = RECEIPTDETAIL.POKey   
    LEFT OUTER JOIN CODELKUP (NOLOCK) ON SKU.SUSR3 = CODELKUP.CODE AND CODELKUP.LISTNAME = 'PRINCIPAL'  
    JOIN #ITEMCLASS t ON t.ReceiptKey = RECEIPT.Receiptkey AND t.SKU = RECEIPTDETAIL.SKU --AND ISNULL(t.UCCNo,'') <> ''  
    --LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (RECEIPT.Storerkey = CLR1.Storerkey AND CLR1.Code = 'HIDESKUBARCODE'  
    --                                   AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_receipt_pre_tallysheet10' AND ISNULL(CLR1.Short,'') <> 'N')  
    --LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPT.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SHOWFIELD'  
    --                                   AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'r_receipt_pre_tallysheet10')  
    LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (RECEIPT.Storerkey = CLR1.Storerkey AND CLR1.Code = 'HIDESKUBARCODE'  
                                       AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'isp_RPT_ASN_PRETALSHT_006' AND ISNULL(CLR1.Short,'') <> 'N')  
    LEFT OUTER JOIN Codelkup CLR2 (NOLOCK) ON (RECEIPT.Storerkey = CLR2.Storerkey AND CLR2.Code = 'SHOWFIELD'  
                                       AND CLR2.Listname = 'REPORTCFG' AND CLR2.Long = 'isp_RPT_ASN_PRETALSHT_006')
    GROUP BY RECEIPT.ReceiptKey,  
             t.Sku , t.Indicator,  
             SKU.SUSR3,  
             CODELKUP.DESCRIPTION,  
             SKU.DESCR,  
             RECEIPTDETAIL.UOM,  
             STORER.Company,  
             RECEIPT.ReceiptDate,  
             RECEIPTDETAIL.PackKey,  
             SKU.SUSR3,  
             RECEIPT.WarehouseReference,  
             PACK.CaseCnt,  
             PACK.Pallet,  
             PACK.PackUOM3,  
             PACK.PackUOM1,  
             PACK.PackUOM2,  
             PACK.PackUOM4,  
             Pack.Innerpack,  
             RECEIPT.ExternReceiptkey,  
             --ISNULL(CL1.Short,''),  
             --ISNULL(CL2.Short,''),  
             --ISNULL(CL3.Short,''),  
             RECEIPTDETAIL.Lottable04,  
             t.ItemClass,  
             t.PalletPosition,  
            -- t.CountPallet,  
             t.TTLQTY,  
             ISNULL(t.UCCNoCnt,0) ,  
             t.UCCUDF08,--t.UCCNo ,  
             CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END,  
             --PO.Userdefine02,         
             PO.SellersReference,     
             ISNULL(CLR2.SHORT,''),
             t.StorerKey
   ORDER BY RECEIPT.Receiptkey,  
             t.PalletPosition desc,  
             t.SKU  
  
  
  DROP TABLE #ITEMCLASS  
  DROP TABLE #ITEMCLASS1  
  --DROP TABLE #ITEMCLASS2  
  
  
   IF CURSOR_STATUS('LOCAL' , 'cur_Loop') in (0 , 1)  
   BEGIN  
      CLOSE cur_Loop  
      DEALLOCATE cur_Loop  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RPT_ASN_PRETALSHT_006'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR      
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
  
   WHILE @@TRANCOUNT < @n_StartTCnt  
      BEGIN TRAN;  

END -- procedure    


GO