SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_ReceiptTallySheet84                            */
/* Creation Date: 05-Nov-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-18294 - SG ADIDAS Tally Sheet                           */
/*                                                                      */
/* Called By: r_receipt_tallysheet84                                    */
/*                                                                      */
/* GitLab Version: 1.1                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 05-Nov-2021  WLChooi 1.0   DevOps Combine Script                     */
/* 26-Jan-2022  WLChooi 1.1   Bug Fix - Remove condition (WL01)         */
/* 26-Jan-2022  Mingle  1.2   WMS-18686 Add new logic(ML01)             */ 
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptTallySheet84] (
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

   DECLARE @c_Receiptkey         NVARCHAR(10)
         , @c_SKU                NVARCHAR(20)
         , @c_ExternReceiptkey   NVARCHAR(50)
         , @c_UCCUDF07           NVARCHAR(50)
         , @c_UCCUDF09           NVARCHAR(50)
         , @c_SKUSUSR2           NVARCHAR(50)
         , @c_UCCStatus          NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @n_NoOfUCC            FLOAT = 0.0
         , @n_UCCQty             INT
         , @n_QtyExp             INT
         , @n_Continue           INT = 1
         , @c_country            NVARCHAR(20) = 'ID'  --ML01

   IF EXISTS (SELECT 1
              FROM RECEIPTDETAIL RD (NOLOCK)
              JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.Sku
              WHERE RD.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd
              AND S.PutawayZone NOT LIKE 'ADI%')
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1    
              FROM RECEIPTDETAIL RD (NOLOCK)    
              JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.Sku    
              WHERE RD.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd    
              AND S.PutawayZone NOT IN (SELECT DISTINCT PZ.PutawayZone     
                                        FROM PutawayZone PZ (NOLOCK)     
                                        WHERE PZ.facility = 'EX5' AND PZ.[Floor] = '6')     
              AND NOT EXISTS (SELECT 1    
                     FROM SKUxLOC SL (NOLOCK)  
                     WHERE SL.StorerKey = RD.StorerKey   
                     AND SL.SKU = RD.Sku    
                     AND SL.LocationType = 'PICK') )   
   BEGIN    
      GOTO QUIT_SP    
   END  

   --START ML01
   IF @c_country = 'ID' AND EXISTS (SELECT 1    
              FROM RECEIPTDETAIL RD (NOLOCK)    
              JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.Sku    
              WHERE RD.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd    
              AND S.PutawayZone NOT IN (SELECT DISTINCT PZ.PutawayZone     
                                        FROM PutawayZone PZ (NOLOCK)     
                                        WHERE PZ.facility = 'PDU03' AND PZ.[Floor] = '6')     
              AND NOT EXISTS (SELECT 1    
                     FROM SKUxLOC SL (NOLOCK)  
                     WHERE SL.StorerKey = RD.StorerKey   
                     AND SL.SKU = RD.Sku    
                     AND SL.LocationType = 'PICK') )   
   BEGIN    
      GOTO QUIT_SP    
   END    
   --END ML01

   CREATE TABLE #TMP_RD (
      CarrierReference     NVARCHAR(50)
    , ContainerType        NVARCHAR(50)
    , ContainerKey         NVARCHAR(50)
    , VehicleNumber        NVARCHAR(50)
    , ToLoc                NVARCHAR(20)
    , SKU                  NVARCHAR(20)
    , SKUDESCR             NVARCHAR(250)
    , ReceiptKey           NVARCHAR(10)
    , ReceiptDate          DATETIME
    , ExternReceiptKey     NVARCHAR(50)
    , STCompany            NVARCHAR(100)
    , PutawayZone          NVARCHAR(50)
    , BlackListStatus      NVARCHAR(20)
    , NoOfPalletPos        INT
    , UCCStatus            NVARCHAR(10)
    , NoOfUCC              NVARCHAR(200)
    , Storerkey            NVARCHAR(15)
    , PreparedBy           NVARCHAR(200)
    , UCCQty               NVARCHAR(200)
    , QtyExpected          INT
    , SplitStatus          NVARCHAR(10)
   )

   INSERT INTO #TMP_RD (CarrierReference, ContainerType, ContainerKey, VehicleNumber, ToLoc, SKU, SKUDESCR, ReceiptKey
                      , ReceiptDate, ExternReceiptKey, STCompany, PutawayZone, BlackListStatus, NoOfPalletPos, UCCStatus, NoOfUCC
                      , Storerkey, PreparedBy, UCCQty, QtyExpected, SplitStatus)
   SELECT ISNULL(R.CarrierReference,'') AS CarrierReference
        , ISNULL(R.ContainerType,'')    AS ContainerType
        , ISNULL(R.ContainerKey,'')     AS ContainerKey
        , ISNULL(R.VehicleNumber,'')    AS VehicleNumber
        , (SELECT MAX(ToLoc) 
           FROM RECEIPTDETAIL (NOLOCK) 
           WHERE RECEIPTDETAIL.ReceiptKey = R.ReceiptKey) AS ToLoc
        , RD.SKU
        , ISNULL(S.DESCR,'') AS SKUDESCR
        , R.ReceiptKey
        , R.ReceiptDate
        , R.ExternReceiptKey
        , ISNULL(ST.Company,'') AS STCompany
        , ISNULL(S.PutawayZone,'') AS PutawayZone
        , CASE WHEN BL.Blacklisted > 0 THEN 'BLACKLISTED' ELSE '' END AS BlackListStatus
        , PL.NoOfPalletPos
        , '' AS UCCStatus
        , '' AS NoOfUCC
        , R.StorerKey
        , SUSER_SNAME() AS PreparedBy
        , '' AS UCCQty
        , SUM(RD.QtyExpected) AS QtyExpected
        , '' AS SplitStatus
   FROM RECEIPT R (NOLOCK)
   JOIN RECEIPTDETAIL RD (NOLOCK) ON R.ReceiptKey = RD.ReceiptKey
   JOIN SKU S (NOLOCK) ON S.StorerKey = RD.StorerKey AND S.SKU = RD.Sku
   JOIN STORER ST (NOLOCK) ON ST.StorerKey = R.StorerKey
   OUTER APPLY (SELECT COUNT(1) AS Blacklisted
                FROM STORER (NOLOCK)
                WHERE STORER.[Type] = '5'
                AND STORER.StorerKey = R.SellerName
                AND STORER.SUSR1 = '1') AS BL
   OUTER APPLY (SELECT COUNT(1) AS NoOfPalletPos
                FROM CODELKUP (NOLOCK)
                WHERE CODELKUP.LISTNAME = 'PreRcvLane'
                AND CODELKUP.StorerKey = R.StorerKey
                AND CODELKUP.Short NOT IN ('R') ) AS PL
   WHERE R.StorerKey BETWEEN @c_StorerkeyStart AND @c_StorerkeyEnd
   AND R.ReceiptKey BETWEEN @c_ReceiptkeyStart AND @c_ReceiptkeyEnd
   GROUP BY ISNULL(R.CarrierReference,'')
          , ISNULL(R.ContainerType,'')   
          , ISNULL(R.ContainerKey,'')    
          , ISNULL(R.VehicleNumber,'')   
          , RD.SKU
          , ISNULL(S.DESCR,'')
          , R.ReceiptKey
          , R.ReceiptDate
          , R.ExternReceiptKey
          , ISNULL(ST.Company,'')
          , ISNULL(S.PutawayZone,'')
          , CASE WHEN BL.Blacklisted > 0 THEN 'BLACKLISTED' ELSE '' END
          , PL.NoOfPalletPos
          , R.StorerKey

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.ReceiptKey, R.SKU, R.ExternReceiptKey
        , ISNULL(U.Userdefined07,''), ISNULL(U.Userdefined09,''), ISNULL(S.SUSR2,'')
        , R.Storerkey
   FROM #TMP_RD R (NOLOCK)
   JOIN UCC U (NOLOCK) ON U.Storerkey = R.StorerKey AND U.SKU = R.Sku
                      AND U.ExternKey = R.ExternReceiptkey
                      --AND U.[Status] >= 1   --WL01
   JOIN SKU S (NOLOCK) ON S.Storerkey = R.StorerKey AND S.SKU = R.Sku
   GROUP BY R.ReceiptKey, R.SKU, R.ExternReceiptKey
          , ISNULL(U.Userdefined07,''), ISNULL(U.Userdefined09,''), ISNULL(S.SUSR2,'')
          , R.Storerkey
   ORDER BY R.ReceiptKey, R.Sku

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_SKU, @c_ExternReceiptkey, @c_UCCUDF07, @c_UCCUDF09, @c_SKUSUSR2, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_UCCStatus = ''
      SET @n_NoOfUCC   = 0

      --SELECT @c_SKU, @c_ExternReceiptkey, @c_UCCUDF07, @c_UCCUDF09, @c_SKUSUSR2, @c_Storerkey

      IF @c_SKUSUSR2 = '1'
      BEGIN
         SET @c_UCCStatus = 'HV'

         SELECT @n_NoOfUCC = COUNT(1)
              , @n_UCCQty  = SUM(U.qty)
         FROM UCC U (NOLOCK)
         WHERE U.Storerkey = @c_Storerkey
         AND U.SKU = @c_SKU
         AND U.ExternKey = @c_ExternReceiptkey
         AND U.Userdefined07 <> '1'
         AND U.Userdefined09 <> '1'
      END
      ELSE IF @c_UCCUDF09 = '1'
      BEGIN
         SET @c_UCCStatus = 'QC'

         SELECT @n_NoOfUCC = COUNT(1)
              , @n_UCCQty  = SUM(U.qty)
         FROM UCC U (NOLOCK)
         WHERE U.Storerkey = @c_Storerkey
         AND U.SKU = @c_SKU
         AND U.ExternKey = @c_ExternReceiptkey
         AND U.Userdefined09 = '1'
      END
      ELSE IF @c_UCCUDF07 = '1'
      BEGIN
         SET @c_UCCStatus = 'M'

         SELECT @n_NoOfUCC = COUNT(1)
              , @n_UCCQty  = SUM(U.qty)
         FROM UCC U (NOLOCK)
         WHERE U.Storerkey = @c_Storerkey
         AND U.SKU = @c_SKU
         AND U.ExternKey = @c_ExternReceiptkey
         AND U.Userdefined07 = '1'

         --SET @n_NoOfUCC = @n_NoOfUCC * 0.5
      END
      ELSE   --Normal
      BEGIN
         SELECT @n_NoOfUCC = COUNT(1)
              , @n_UCCQty  = SUM(U.qty)
         FROM UCC U (NOLOCK)
         WHERE U.Storerkey = @c_Storerkey
         AND U.SKU = @c_SKU
         AND U.ExternKey = @c_ExternReceiptkey
      END

      SELECT @n_QtyExp = SUM(R.QtyExpected)
      FROM #TMP_RD R
      WHERE R.Storerkey = @c_Storerkey
      AND R.SKU = @c_SKU
      AND R.ExternReceiptKey = @c_ExternReceiptkey
      AND R.SplitStatus <> 'Y'

      IF ISNULL(@c_UCCStatus,'') <> ''
      BEGIN
         IF @n_QtyExp > @n_UCCQty
         BEGIN 
            INSERT INTO #TMP_RD(CarrierReference, ContainerType, ContainerKey, VehicleNumber, ToLoc, SKU, SKUDESCR, ReceiptKey
                              , ReceiptDate, ExternReceiptKey, STCompany, PutawayZone, BlackListStatus, NoOfPalletPos, UCCStatus
                              , NoOfUCC, Storerkey, PreparedBy, UCCQty, QtyExpected, SplitStatus)
            SELECT TOP 1
                   CarrierReference, ContainerType, ContainerKey, VehicleNumber, ToLoc, SKU, SKUDESCR, ReceiptKey
                 , ReceiptDate, ExternReceiptKey, STCompany, PutawayZone, BlackListStatus, NoOfPalletPos, @c_UCCStatus
                 , @n_NoOfUCC, Storerkey, PreparedBy, @n_UCCQty, @n_UCCQty, 'Y'
            FROM #TMP_RD
            WHERE ReceiptKey = @c_Receiptkey
            AND SKU = @c_SKU
            AND ExternReceiptKey = @c_ExternReceiptKey
            AND Storerkey = @c_Storerkey 

            UPDATE #TMP_RD
            SET QtyExpected = QtyExpected - @n_UCCQty
            WHERE ReceiptKey = @c_Receiptkey
            AND SKU = @c_SKU
            AND ExternReceiptKey = @c_ExternReceiptKey
            AND Storerkey = @c_Storerkey 
            AND SplitStatus <> 'Y'
         END
         ELSE
         BEGIN
            UPDATE #TMP_RD
            SET UCCStatus = @c_UCCStatus
              , NoOfUCC   = @n_NoOfUCC
              , UCCQty    = @n_QtyExp
            WHERE ReceiptKey = @c_Receiptkey
            AND SKU = @c_SKU
            AND ExternReceiptKey = @c_ExternReceiptKey
            AND Storerkey = @c_Storerkey 
         END
      END
      ELSE
      BEGIN
         UPDATE #TMP_RD
         SET UCCStatus = @c_UCCStatus
           , NoOfUCC   = @n_NoOfUCC
           , UCCQty    = @n_QtyExp
         WHERE ReceiptKey = @c_Receiptkey
         AND SKU = @c_SKU
         AND ExternReceiptKey = @c_ExternReceiptKey
         AND Storerkey = @c_Storerkey 
      END

      FETCH NEXT FROM CUR_LOOP INTO @c_Receiptkey, @c_SKU, @c_ExternReceiptkey, @c_UCCUDF07, @c_UCCUDF09, @c_SKUSUSR2, @c_Storerkey
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP

   SELECT   TR.CarrierReference 
          , TR.ContainerType    
          , TR.ContainerKey     
          , TR.VehicleNumber    
          , TR.ToLoc            
          , TR.SKU              
          , TR.SKUDESCR         
          , TR.ReceiptKey       
          , TR.ReceiptDate      
          , TR.ExternReceiptKey 
          , TR.STCompany        
          , TR.PutawayZone      
          , TR.BlackListStatus  
          , TR.NoOfPalletPos   
          , TR.UCCStatus AS UCCStatus 
          , TR.NoOfUCC AS NoOfUCC
          , TR.PreparedBy
          , TR.QtyExpected
          , TR.UCCQty
          , TR.Storerkey
   FROM #TMP_RD TR
   ORDER BY TR.ReceiptKey
          , TR.PutawayZone
          , TR.Sku
          , CASE WHEN TR.UCCStatus = '' THEN 2 ELSE 1 END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_RD') IS NOT NULL
      DROP TABLE #TMP_RD

   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
END        

GO