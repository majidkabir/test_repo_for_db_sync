SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/    
/* Stored Proc: ispBatPA04                                              */    
/* Creation Date: 05-AUG-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-20404/WMS-21875 - CN NIKE CallofModel ASN Suggest PA    */    
/*        : Modified from ispBATPA03                                    */    
/*        :                                                             */    
/* Called By:                                                           */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 05-Aug-2022 NJOW     1.0   DEVOPS combine script                     */    
/* 26-Jun-2023 JS       1.1   fix logic for FP/HP's max/min carton      */    
/* 22-Sep-2023 JS02     1.2   WMS-23914 Update logic                    */   
/************************************************************************/    
CREATE   PROC [dbo].[ispBatPA04]    
           @c_ReceiptKey     NVARCHAR(MAX)    
         , @b_Success        INT            OUTPUT    
         , @n_Err            INT            OUTPUT    
         , @c_ErrMsg         NVARCHAR(2000) OUTPUT    
         , @b_debug          INT = 0     
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE      
           @n_StartTCnt          INT    
         , @n_Continue           INT     
         , @c_CommitPerSku       NVARCHAR(1)    = ''    
         , @c_Facility           NVARCHAR(5)    = ''    
         , @c_Site               NVARCHAR(30)   = ''    
         , @c_SuggestLoc         NVARCHAR(10)   = ''    
         , @n_SuggestQty         INT            = 0    
         , @c_SourceKey          NVARCHAR(15)   = ''    
         , @c_CurrReceiptkey     NVARCHAR(10)   = ''    
         , @c_ReceiptkeyUpdate   NVARCHAR(10)   = ''    
         , @c_ReceiptLineNumber  NVARCHAR(5)    = ''    
         , @c_PrevReceiptkey     NVARCHAR(10)   = ''    
         , @c_PrevReceiptLineNumber NVARCHAR(5) = ''    
         , @c_Storerkey          NVARCHAR(15)   = ''    
         , @c_Sku                NVARCHAR(20)   = ''    
         , @c_ItemClass          NVARCHAR(10)   = ''    
         , @c_SkuGroup           NVARCHAR(10)   = ''  --JS New param  
         , @c_FromLot            NVARCHAR(10)   = ''    
         , @c_FromLoc            NVARCHAR(10)   = ''    
         , @c_FromID             NVARCHAR(18)   = ''    
         , @c_ToID               NVARCHAR(18)   = ''    
         , @c_ReceiptLineUpdate  NVARCHAR(5)    = ''    
         , @n_PAInsertQty        INT            = 0    
         , @c_PrePackIndicator   NVARCHAR(30)   = ''    
         , @n_PackQtyIndicator   INT            = 0    
         , @n_SkuQtyReceived     INT            = 0    
         , @n_SkuQtyRemaining    INT            = 0    
         , @n_QtyReceived        INT            = 0    
         , @n_ReceiptUCCQTY      INT            = 0  --JS added  
         , @n_LinePAQty          INT            = 0    
         , @n_PAToLocQty         INT            = 0    
         , @c_Lottable01         NVARCHAR(18)   = ''            
         , @c_Lottable02         NVARCHAR(18)   = ''            
         , @c_Lottable03         NVARCHAR(18)   = ''            
         , @d_Lottable04         DATETIME       = NULL          
         , @d_Lottable05         DATETIME       = NULL          
         , @c_Lottable06         NVARCHAR(30)   = ''                        
         , @c_Lottable07         NVARCHAR(30)   = ''                         
         , @c_Lottable08         NVARCHAR(30)   = ''                       
         , @c_Lottable09         NVARCHAR(30)   = ''                      
         , @c_Lottable10         NVARCHAR(30)   = ''                       
         , @c_Lottable11         NVARCHAR(30)   = ''                       
         , @c_Lottable12         NVARCHAR(30)   = ''                      
         , @d_Lottable13         DATETIME       = NULL                    
         , @d_Lottable14         DATETIME       = NULL                    
         , @d_Lottable15         DATETIME       = NULL          
         --, @c_RDLottable02       NVARCHAR(18)   = ''             
         , @n_PABookingKey       INT            = 0    
         , @n_Cnt                INT            = 1    
         , @c_UserName           NVARCHAR(18)   = ''    
         , @n_CaseCnt            INT            = 0    
         , @n_SafetyStockLimit   INT            = 0         
         , @n_SafetyStockSum     INT            = 0    
         , @n_MezzanineB         INT            = 0    
         , @n_MezzanineS         INT            = 0    
         , @n_MezzanineM         INT            = 0    
         , @n_MezzanineX         INT            = 0    
         , @n_MezzanineY         INT            = 0    
         , @n_MezzanineZ         INT            = 0                  
         , @c_MostEmptyLocPickZone     NVARCHAR(10) = ''    
         , @n_SafetyStockPAQty         INT          = 0    
         , @c_SafetyStockPALoc         NVARCHAR(10) = ''    
         , @n_SafetyStockPALocQty      INT          = 0    
         , @n_SafetyStockPALocScore    INT         = 0   --JS  
         , @c_SafetyStockPALocZone     NVARCHAR(10) = '' --JS   
         , @n_RowID                    INT          = 0                  
         , @c_HBStockPALoc             NVARCHAR(10) = ''    
         , @n_HBStockPALocQty          INT          = 0    
         , @n_HB_PACarton              INT          = 0          
         --, @c_FreeSeatsStockPALoc      NVARCHAR(10) = '' --JS02 remove FreeSeats part
         --, @n_FreeSeatsStockPALocQty   INT        = 0 --JS02 remove FreeSeats part
         --, @n_FreeSeatsStockPALocScore NVARCHAR(10) = '' --JS --JS02 remove FreeSeats part
         , @c_ASNType                  NVARCHAR(10)  
         , @c_UCCNo                    NVARCHAR(20)  
         , @n_UCCQty                   INT  
         , @n_TotalPieceQtyTake        INT  
         , @n_TotalCaseQtyTake         INT  
         , @n_RemainTotalPieceQtyTake  INT  
         , @n_TotalPiece               INT  
         , @n_FP_CartonCnt             INT  
         , @n_HP_CartonCnt             INT                
         , @n_PACarton                 INT  
         , @c_ToLoc                    NVARCHAR(10)  
         , @n_RowID_SkuQtySumm         INT  
         , @n_RowID_UCC                INT   --JS2 add rowid for temp ucctable use  
         , @CUR_RDSKU            CURSOR             
             
   IF @b_debug = 1    
      SET @c_CommitPerSku = 'N'             
   ELSE    
      SET @c_CommitPerSku = 'Y'             
                                      
   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @n_err = 0, @c_errmsg = '', @c_UserName = SUSER_SNAME()    
          
   --Validation    
   IF @n_continue IN (1,2)    
   BEGIN    
      IF EXISTS(SELECT 1    
                FROM RECEIPT(NOLOCK)    
                WHERE Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
                HAVING COUNT(DISTINCT Storerkey) > 1)    
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63010    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Selected receipts from more than one storerkey are not allowed'     
                       + '. (ispBatPA04)'    
         GOTO QUIT_SP          
      END    
        
    
      SET @n_Cnt = 1    
      SELECT @n_Cnt = 0    
      FROM RECEIPTDETAIL RD WITH (NOLOCK)    
      WHERE RD.ReceiptKey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
      AND (RD.UserDefine10 = '' OR RD.UserDefine10 IS NULL)    
          
      IF @n_Cnt = 1           
      BEGIN                
         SET @n_Continue = 3    
         SET @n_Err = 63020    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': All Receipt Sku had suggested PA before.'     
                        + '. (ispBatPA04)'     
         GOTO QUIT_SP    
      END     
      SET @n_Cnt = 0          
        
      IF EXISTS(SELECT 1    
                FROM RECEIPT(NOLOCK)    
                WHERE Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
                HAVING COUNT(DISTINCT CarrierReference) > 1)    
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63030    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Not allow select multiple ASN types, it must be all Case or Piece (CarrierReference)'     
                       + '. (ispBatPA04)'    
         GOTO QUIT_SP          
      END    
           
     -------JS added valdation to check if Receipt Detail without ToLoc  
     IF EXISTS(SELECT 1    
                FROM RECEIPTDETAIL(NOLOCK)    
                WHERE Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
                AND ISNULL(ToLoc,'')='')    
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63040    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Not allow Receipt Detail ToLoc is empty'     
                       + '. (ispBatPA04)'    
         GOTO QUIT_SP          
      END    
  
      SET @c_Sku = ''  
      SELECT TOP 1 @c_Sku = RD.Sku   
      FROM RECEIPT R(NOLOCK)    
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey  
      JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku  
      OUTER APPLY (SELECT TOP 1 Cube FROM CARTONIZATION CZ (NOLOCK)   
                   WHERE SKU.CartonGroup = CZ.CartonizationGroup) AS CARNIZ                  
      WHERE R.Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))  
      AND (ISNULL(SKU.Cube,0) = 0 OR ISNULL(CARNIZ.Cube,0) = 0)  
      ORDER BY RD.Sku  
                 
      IF @c_Sku <> ''  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63050    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Sku: '+ RTRIM(@c_Sku) + ' does not has proper cube settings (CarrierReference)'     
                       + '. (ispBatPA04)'    
         GOTO QUIT_SP          
      END  
     
     ----JS added sku config check  
     SET @c_Sku = ''  
      SELECT TOP 1 @c_Sku = RD.Sku   
      FROM RECEIPT R(NOLOCK)    
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey  
      LEFT JOIN SKUCONFIG SC (NOLOCK) ON RD.Storerkey = SC.Storerkey AND RD.Sku = SC.Sku AND SC.ConfigType = 'NK-PUTAWAY'   
      WHERE R.Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))  
      AND ISNULL(SC.SKU,'') = ''  
      ORDER BY RD.Sku  
                 
      IF @c_Sku <> ''  
      BEGIN    
         SET @n_Continue = 3    
         SET @n_Err = 63060    
         SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Sku: '+ RTRIM(@c_Sku) + ' does not has SKUCONFIG settings'     
                       + '. (ispBatPA04)'    
         GOTO QUIT_SP          
      END  
   END    
     
   --Populate loc info to temporary working table and retrieve common data    
   IF @n_continue IN(1,2)    
   BEGIN        
      CREATE TABLE #TMP_PALOC (  RowID            INT      IDENTITY(1,1)  PRIMARY KEY    
                              ,  LOC              NVARCHAR(10)    
                              ,  LocationRoom     NVARCHAR(30)    
                              ,  LogicalLocation  NVARCHAR(18)       
                              ,  PickZone         NVARCHAR(10)   
                              ,  PutawayZone      NVARCHAR(10)   --JS   
                              ,  Score            INT            --JS   
                              ,  LocationCategory NVARCHAR(10)      
                              ,  Priority         NVARCHAR(10)    
                              ,  CartonCnt        INT    
                              ,  FP_CartonCnt     INT    
                              ,  HP_CartonCnt     INT    
                              ,  Sku              NVARCHAR(20)    
                              ,  ItemClass        NVARCHAR(10)    
                              ,  Qty              INT)                                          
      CREATE INDEX IDX_PALOC ON #TMP_PALOC (LocationRoom, LocationCategory, PickZone, Sku, PutawayZone) --JS add PutawayZone  
      CREATE INDEX IDX_PAIC ON #TMP_PALOC (ItemClass, PutawayZone)  --JS add PutawayZone  
        
      CREATE TABLE #TMP_UCC (  RowID            INT      IDENTITY(1,1)  PRIMARY KEY    
                            ,  Storerkey        NVARCHAR(15)    
                            ,  Sku              NVARCHAR(20)    
                            ,  UccNo            NVARCHAR(20)  
                            ,  Qty              INT  
                            ,  SuggestLoc       NVARCHAR(10))             
      CREATE INDEX IDX_UCCNO ON #TMP_UCC (UCCNo)   
          
      CREATE TABLE #TMP_SKUQTYSUMM (  RowID            INT      IDENTITY(1,1)  PRIMARY KEY    
                                   ,  Storerkey        NVARCHAR(15)    
                                   ,  Sku              NVARCHAR(20)    
                                   ,  TotalQty         INT  
                                   ,  CaseCnt          INT  
                                   ,  TotalCase        INT  
                                   ,  TotalPiece       INT)          
      CREATE INDEX IDX_SKU ON #TMP_SKUQTYSUMM (Storerkey, Sku, CaseCnt)   
          
      SELECT TOP 1 @c_Facility = RH.Facility    
                  ,@c_Storerkey = RH.Storerkey     
                  ,@c_Site = RTRIM(RH.UserDefine01)    
                  ,@c_ASNType = CASE WHEN ISNULL(RH.CarrierReference,'') = 'CASE' THEN 'CASE' ELSE 'PIECE' END  
      FROM RECEIPT RH WITH (NOLOCK)     
      WHERE RH.ReceiptKey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))          
          
      INSERT INTO #TMP_PALOC (LOC, LocationRoom, LogicalLocation, PickZone, PutawayZone, Score, LocationCategory   --JS add PutawayZone,Score  
                   ,Priority    
                   ,CartonCnt    
                   ,FP_CartonCnt     
                   ,HP_CartonCnt    
                   ,Sku, ItemClass, Qty)    
      SELECT LOC.Loc, LOC.LocationRoom, LOC.LogicalLocation, LOC.PickZone, LOC.PutawayZone, LOC.Score, LOC.LocationCategory,   --JS add PutawayZone  
             ISNULL(CL.Short,'') AS Priority,     
             CASE WHEN ISNUMERIC(CL.UDF01) = 1 THEN CAST(CL.UDF01 AS INT) ELSE 0 END AS CartonCnt,     
             CASE WHEN ISNUMERIC(CL.UDF02) = 1 THEN CAST(CL.UDF02 AS INT) ELSE 0 END AS FP_CartonCnt,     
             CASE WHEN ISNUMERIC(CL.UDF03) = 1 THEN CAST(CL.UDF03 AS INT) ELSE 0 END AS HP_CartonCnt,     
             ISNULL(INV.Sku,''), ISNULL(INV.ItemClass,''), ISNULL(INV.Qty,0)    
      FROM LOC (NOLOCK)           
      JOIN CODELKUP CL (NOLOCK) ON LOC.PickZone = CL.Code2      
      OUTER APPLY (SELECT MAX(LLI.Sku) AS Sku,    
                          MAX(SKU.ItemClass) AS ItemClass,    
                          SUM (LLI.Qty + LLI.PendingMoveIn - LLI.QtyPicked) AS Qty    ---JS add - LLI.QtyPicked  
                   FROM LOTXLOCXID LLI (NOLOCK)     
                   JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku    
                   WHERE LLI.Loc = LOC.Loc    
                   AND LLI.Storerkey = @c_Storerkey    
                   --AND LLI.Qty + LLI.PendingMoveIn > 0) AS INV 
                   AND (LLI.Qty + LLI.PendingMoveIn - LLI.QtyPicked) > 0) AS INV  --JS ver1.1 should also -LLI.QTYPicked
      WHERE CL.ListName = 'NIKEPAPICK'    
      AND CL.UDF04 = 'Y'   
      AND CL.Code = @c_Site    
      AND LOC.Facility = @c_Facility    
      AND LOC.LocationRoom IN ('SAFETYSTOCK','HIGHBAY')  --'FREESEATS' --JS02 remove FreeSeats part     
      AND LOC.LocationHandling <> 'INUSE'   --JS added to filter CASE type used LOC  
        
    IF @c_ASNType = 'CASE'  --By UCC  
    BEGIN    
      --Get the ASN UCC       
       INSERT INTO #TMP_UCC (Storerkey, Sku, UCCNo, Qty, SuggestLoc)  
       SELECT DISTINCT RD.Storerkey, RD.Sku, UCC.UccNo, UCC.Qty, ''  
         FROM RECEIPT R(NOLOCK)    
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey  
         JOIN UCC (NOLOCK) ON UCC.Storerkey = RD.Storerkey AND UCC.Sku = RD.Sku  
                              AND UCC.Externkey = RD.ExternReceiptkey  
                              AND UCC.Userdefined08 = RD.Userdefine03  
                              AND UCC.Userdefined09 = RD.Userdefine04  
         WHERE R.Receiptkey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))  
                    
         --Get the Sku PA Qty Summary by Case and Piece  
         INSERT INTO #TMP_SKUQTYSUMM (Storerkey, SKU, TotalQty, CaseCnt, TotalCase, TotalPiece)           
         SELECT Storerkey, SKU, SUM(Qty), Qty, COUNT(DISTINCT UCCNo), 0              
         FROM #TMP_UCC                                            
         GROUP BY Storerkey, SKU, Qty                    
           
         --Remove mix sku UCC and update SKU PA Qty Summary as piece qty  
         DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
            SELECT UCCNo  
            FROM #TMP_UCC  
            GROUP BY UCCNo  
            HAVING COUNT(SKU) > 1                      
  
         OPEN CUR_UCC                                              
                                                                      
         FETCH NEXT FROM CUR_UCC INTO @c_UCCNo  
                                                                      
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)          
         BEGIN                                            
            DECLARE CUR_UCCSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
              SELECT Storerkey, Sku, Qty     --JS should be Qty  
              FROM #TMP_UCC  
              WHERE UccNo = @c_UCCNo  
  
            OPEN CUR_UCCSKU      --JS missed OPEN  
          
            FETCH NEXT FROM CUR_UCCSKU INTO @c_Storerkey, @c_Sku, @n_CaseCnt                        
              
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)         
            BEGIN                                                       
              UPDATE #TMP_SKUQTYSUMM  
              SET TotalCase = TotalCase - 1,  
                  TotalPiece = TotalPiece + @n_CaseCnt  
              WHERE Storerkey = @c_Storerkey  
              AND Sku = @c_Sku  
              AND CaseCnt = @n_CaseCnt      
                
               FETCH NEXT FROM CUR_UCCSKU INTO @c_Storerkey, @c_Sku, @n_CaseCnt                        
            END           
            CLOSE CUR_UCCSKU  
            DEALLOCATE CUR_UCCSKU              
              
            UPDATE #TMP_UCC SET SuggestLoc = 'MIXSKU' WHERE UCCNo = @c_UCCNo  
              
            FETCH NEXT FROM CUR_UCC INTO @c_UCCNo  
         END  
         CLOSE CUR_UCC  
         DEALLOCATE CUR_UCC  
      END        
   END    
       
   IF @b_debug = 1    
   BEGIN    
      PRINT '@c_Storerkey' + @c_Storerkey + ' @c_Facility=' + @c_Facility + ' @c_Site=' + @c_Site    
      SELECT * FROM #TMP_PALOC    
   END    
       
   IF @c_CommitPerSku = 'Y'     
      WHILE @@TRANCOUNT > 0    
         COMMIT TRAN    
          
   --BEGIN TRY    
      IF @c_CommitPerSku = 'Y' OR @n_StartTCnt = 0  --to avoid transaction closing when run isp_lostID which is nice to have process.     
         EXEC isp_LostID 1, @c_Storerkey, @c_Facility         
   --END TRY    
   --BEGIN CATCH    
   --   IF @@TRANCOUNT < @n_StartTCnt    
   --   BEGIN    
   --      BEGIN TRAN    
   --   END    
   --END CATCH    
  
   SET @CUR_RDSKU = CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT RD.Storerkey    
         ,RD.Sku    
         ,ItemClass = ISNULL(RTRIM(S.ItemClass),'')    
         ,SkuGroup = ISNULL(RTRIM(S.SkuGroup),'')  --JS  
         ,SkuQtyReceived = ISNULL(SUM(CASE WHEN RD.Beforereceivedqty > 0 THEN RD.Beforereceivedqty ELSE RD.QtyExpected END),0)    
         ,PrePackIndicator = S.PrePackIndicator     
         ,PackQtyIndicator = S.PackQtyIndicator    
         ,FLOOR(CARNIZ.Cube / S.Cube) --P.CaseCnt    
         --,Lottable02 = RD.Lottable02    
   FROM RECEIPT RH WITH (NOLOCK)     
   JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RH.Receiptkey = RD.ReceiptKey    
   JOIN SKU  S WITH (NOLOCK) ON  RD.Storerkey = S.Storerkey AND RD.Sku = S.Sku    
   JOIN PACK P WITH (NOLOCK) ON  S.Packkey = P.Packkey    
   OUTER APPLY (SELECT TOP 1 Cube FROM CARTONIZATION CZ (NOLOCK)   
                WHERE S.CartonGroup = CZ.CartonizationGroup) AS CARNIZ                  
   WHERE RH.ReceiptKey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
   AND  (RD.QtyExpected > 0 OR RD.Beforereceivedqty > 0)    
   AND  (RD.UserDefine10 = '' OR RD.Userdefine10 IS NULL)       
   GROUP BY RD.Storerkey    
         ,  RD.Sku    
         ,  ISNULL(RTRIM(S.ItemClass),'')    
         ,  ISNULL(RTRIM(S.SkuGroup),'')  --JS  
         ,  S.PrePackIndicator     
         ,  S.PackQtyIndicator    
         --,  P.CaseCnt  --JS no need this  
         ,  CARNIZ.[Cube]  
         ,  S.[Cube]  
         --,  RD.Lottable02    
   ORDER BY RD.Storerkey, RD.Sku    
    
   OPEN @CUR_RDSKU    
       
   FETCH NEXT FROM @CUR_RDSKU INTO @c_Storerkey    
                                 , @c_Sku    
                                 , @c_ItemClass     
                                 , @c_SkuGroup  --JS  
                                 , @n_SkuQtyReceived      
                                 , @c_PrePackIndicator    
                                 , @n_PackQtyIndicator    
                                 , @n_CaseCnt    
                                 --, @c_RDLottable02    
    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF @b_debug =  1    
      BEGIN    
         PRINT '***@c_Sku=' + @c_Sku  + ' @c_itemclass=' + @c_ItemClass + ' @c_SkuGroup=' + @c_SkuGroup + ' @n_SkuQtyReceived=' + CAST(@n_SkuQtyReceived AS NVARCHAR)    
         PRINT '@c_PrePackIndicator=' + @c_PrePackIndicator + ' @n_PackQtyIndicator=' + CAST(@n_PackQtyIndicator AS NVARCHAR) + ' @n_Casecnt=' + CAST(@n_CaseCnt AS NVARCHAR)    
      END        
        
      IF @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0    
      BEGIN    
        SET @n_CaseCnt = FLOOR(@n_CaseCnt / @n_PackQtyIndicator) * @n_PackQtyIndicator   ---JS cube will be sku cube, and for innerpack casecnt need be multi innerpackqty  
        SET @n_SkuQtyReceived = FLOOR(@n_SkuQtyReceived / @n_PackQtyIndicator) * @n_PackQtyIndicator     
        IF @n_SkuQtyReceived = 0     
           GOTO NEXT_SKU    
      END    
         
     IF @b_debug =  1    
      BEGIN    
         PRINT 'After PackQtyIndicator @n_Casecnt=' + CAST(@n_CaseCnt AS NVARCHAR)    
      END      
     
      IF @c_CommitPerSku = 'Y'    
         BEGIN TRAN        
              
      --Retrieve settings for the sku    
      IF @n_continue IN(1,2)    
      BEGIN    
         SET @n_PABookingKey = 0    
         SET @c_ReceiptLineNumber = ''    
         SET @n_SkuQtyRemaining = @n_SkuQtyReceived    
         SET @c_SuggestLoc = ''    
         SET @n_SuggestQty = 0    
         SET @n_SafetyStockLimit = 0         
         SET @n_SafetyStockSum = 0    
         SET @n_MezzanineB = 0    
         SET @n_MezzanineS = 0    
         SET @n_MezzanineM = 0    
         SET @n_MezzanineX = 0    
         SET @n_MezzanineY = 0    
         SET @n_MezzanineZ = 0                  
         SET @c_MostEmptyLocPickZone = ''    
         SET @c_SafetyStockPALocZone = ''     --JS add param   
         SET @n_SafetyStockPALocScore = 0     --JS add param   
         --SET @n_FreeSeatsStockPALocScore = 0  --JS add param  --JS02 remove FreeSeats part
             
         SELECT @n_MezzanineX = CASE WHEN ISNUMERIC(SC.UserDefine01) = 1 THEN CAST(SC.UserDefine01 AS INT) ELSE 0 END,    
                @n_MezzanineY = CASE WHEN ISNUMERIC(SC.UserDefine02) = 1 THEN CAST(SC.UserDefine02 AS INT) ELSE 0 END,          
                @n_MezzanineM = CASE WHEN ISNUMERIC(SC.UserDefine03) = 1 THEN CAST(SC.UserDefine03 AS INT) ELSE 0 END,          
                @n_MezzanineB = CASE WHEN ISNUMERIC(SC.UserDefine04) = 1 THEN CAST(SC.UserDefine04 AS INT) ELSE 0 END,          
                @n_MezzanineS = CASE WHEN ISNUMERIC(SC.UserDefine05) = 1 THEN CAST(SC.UserDefine05 AS INT) ELSE 0 END,          
                @n_MezzanineZ = CASE WHEN ISNUMERIC(SC.UserDefine08) = 1 THEN CAST(SC.UserDefine08 AS INT) ELSE 0 END,          
                @n_SafetyStockLimit = CASE WHEN ISNUMERIC(SC.UserDefine10) = 1 THEN CAST(SC.UserDefine10 AS INT) ELSE 0 END    
         FROM SKUCONFIG SC (NOLOCK)    
         WHERE SC.Storerkey = @c_Storerkey    
         AND SC.Sku = @c_Sku    
         AND SC.ConfigType = 'NK-PUTAWAY'    
             
         SELECT @n_SafetyStockSum = ISNULL(SUM(Qty),0)    
         FROM #TMP_PALOC     
         WHERE LocationRoom = 'SAFETYSTOCK'    
         AND Sku = @c_Sku    
             
         IF @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0    
         BEGIN    
            SET @n_MezzanineB = FLOOR(@n_MezzanineB / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_MezzanineS = FLOOR(@n_MezzanineS / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_MezzanineM = FLOOR(@n_MezzanineM / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_MezzanineX = FLOOR(@n_MezzanineX / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_MezzanineY = FLOOR(@n_MezzanineY / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_MezzanineZ = FLOOR(@n_MezzanineZ / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_SafetyStockLimit = FLOOR(@n_SafetyStockLimit / @n_PackQtyIndicator) * @n_PackQtyIndicator     
            SET @n_SafetyStockSum = CEILING(@n_SafetyStockSum / @n_PackQtyIndicator) * @n_PackQtyIndicator     
         END    
             
         SELECT TOP 1 @c_MostEmptyLocPickZone = T.PickZone     
         FROM #TMP_PALOC T     
         WHERE T.Qty = 0   
         AND T.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup   
         GROUP BY T.PickZone    
         ORDER BY COUNT(DISTINCT T.Loc) DESC                
           
         --SELECT TOP 1 @n_SafetyStockPALocScore = T.Score     --JS Add  found score first   
         --            ,@c_SafetyStockPALocZone = T.PickZone   --JS Add  found score first   
         --FROM #TMP_PALOC T   
         --WHERE T.LocationRoom = 'SAFETYSTOCK' AND T.ItemClass = @c_ItemClass AND T.Qty > 0  
         --ORDER BY (CASE WHEN T.Sku = @c_Sku THEN 0 ELSE 1 END), T.Score  
         
		     --JS02 remove FreeSeats part
         --SELECT TOP 1 @n_FreeSeatsStockPALocScore = T.Score    --JS Add  found score first   
         --FROM #TMP_PALOC T   
         --WHERE T.LocationRoom = 'FREESEATS' AND T.SKU = @c_Sku AND T.Qty > 0  
         --ORDER BY T.Score  
         
         IF @b_debug = 1    
         BEGIN    
            PRINT '@n_MezzanineB=' + CAST(@n_MezzanineB AS NVARCHAR) + ' @n_MezzanineS=' + CAST(@n_MezzanineS AS NVARCHAR) + ' @n_MezzanineM=' + CAST(@n_MezzanineM AS NVARCHAR)    
            PRINT '@n_MezzanineX=' + CAST(@n_MezzanineX AS NVARCHAR) + ' @n_MezzanineY=' + CAST(@n_MezzanineY AS NVARCHAR) + ' @n_MezzanineZ=' + CAST(@n_MezzanineZ AS NVARCHAR)    
            PRINT '@n_SafetyStockSum=' + CAST(@n_SafetyStockSum AS NVARCHAR) + ' @n_SafetyStockLimit=' + CAST(@n_SafetyStockLimit AS NVARCHAR) + ' @c_MostEmptyLocPickZone=' + @c_MostEmptyLocPickZone    
            --PRINT '@n_SafetyStockPALocScore=' + CAST(@n_SafetyStockPALocScore AS NVARCHAR) + ' @c_SafetyStockPALocZone=' + CAST(@c_SafetyStockPALocZone AS NVARCHAR)   
         END    
      END    
                
      SET @n_LinePAQty = 0    
      SET @c_ReceiptLineNumber = ''    
      SET @c_CurrReceiptkey = ''    
      SET @c_PrevReceiptkey = ''    
      SET @c_PrevReceiptLineNumber = ''                            
      --Putaway process for the sku    
      WHILE @n_SkuQtyRemaining > 0     
      BEGIN     
         SELECT @c_SuggestLoc = '', @n_SuggestQty = 0, @n_RowID = 0    
             
         IF @b_debug = 1     
         BEGIN    
            PRINT ''    
            PRINT '@n_SkuQtyRemaining=' + CAST(@n_SkuQtyRemaining AS NVARCHAR)    
         END    
             
         ---Safetystock PA     
		 /*JS02 remove safetystock part at first*/
		 /*
         IF @n_continue IN(1,2) AND @c_SuggestLoc = ''    
         BEGIN 
            SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0, @n_RowID = 0    
                
            SET @n_SafetyStockPAQty = @n_SafetyStockLimit - @n_SafetyStockSum    
    
            IF @b_debug = 1     
            BEGIN    
               PRINT '1---SAFETYSTOCK PA '    
               PRINT '@n_SafetyStockPAQty=' + CAST(@n_SafetyStockPAQty AS NVARCHAR)    
            END    
    
           IF @n_SafetyStockPAQty > 0    
           BEGIN                
              --Find same sku    
              IF @c_SuggestLoc = ''    
              BEGIN    
  
                 SELECT TOP 1 @n_RowID = RowID,    
                        @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                      WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                      WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                      WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                      WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                      WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                      ELSE 0 END - TPA.Qty,    
                        @c_SafetyStockPALoc = TPA.Loc,  
                        @c_SafetyStockPALocZone = TPA.PickZone,    --JS add param  
                        @n_SafetyStockPALocScore = TPA.Score       --JS add param  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup   
                 AND TPA.Qty < CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                    WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                    WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                    WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                    WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                    WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                    ELSE 0 END     
                 AND TPA.Sku = @c_Sku    
                 ORDER BY TPA.LogicalLocation, TPA.Loc    
                     
                 IF @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0 AND @n_SafetyStockPALocQty > 0    
                 BEGIN    
                    SET @n_SafetyStockPALocQty = FLOOR(@n_SafetyStockPALocQty / @n_PackQtyIndicator) * @n_PackQtyIndicator     
                 END    
                      
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    
           
                    --JS some time @n_SkuQtyRemaining more then @n_SafetyStockPALocQty and @n_SafetyStockPALocQty   
                    --IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                    --   SET @n_SuggestQty = @n_SkuQtyRemaining    
                    --ELSE       
                    --   SET @n_SuggestQty = @n_SafetyStockPALocQty      
                
                    IF @n_SkuQtyRemaining < @n_SafetyStockPAQty    
                    BEGIN  
                    IF @n_SkuQtyRemaining > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    END  
                    ELSE   
                    BEGIN  
                    IF @n_SafetyStockPAQty > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SafetyStockPAQty         
                    END     
                 END      
                     
                 IF @b_debug = 1    
                 BEGIN    
                     PRINT 'Find Same Sku @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END    
              END    
                  
              --Find same pickzone of same itemclass    
              IF @c_SuggestLoc = ''    
              BEGIN                     
                 SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0    
                     
                 SELECT TOP 1 @n_RowID = RowID,    
                       @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                     WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                     WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                     WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                     WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                     WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                     ELSE 0 END,    
                       @c_SafetyStockPALoc = TPA.Loc,  
                       @c_SafetyStockPALocZone = TPA.PickZone,   ---JS add param  
                       @n_SafetyStockPALocScore = TPA.Score ---JS add param  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup     
                 AND TPA.PickZone IN (SELECT DISTINCT T.Pickzone     
                                      FROM #TMP_PALOC T     
                                      WHERE T.ItemClass = @c_ItemClass    
                                      AND T.Qty > 0)    
                 AND TPA.PickZone = CASE WHEN @c_SafetyStockPALocZone = '' THEN TPA.PickZone ELSE @c_SafetyStockPALocZone END --JS   
                 AND TPA.Qty = 0    
                 ORDER BY ABS(TPA.Score - @n_SafetyStockPALocScore), TPA.LogicalLocation, TPA.Loc  --JS add order ABS score             
                                     
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    
       
                    --JS some time @n_SkuQtyRemaining more then @n_SafetyStockPALocQty and @n_SafetyStockPALocQty   
                    --IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                    --   SET @n_SuggestQty = @n_SkuQtyRemaining    
                    --ELSE       
                    --   SET @n_SuggestQty = @n_SafetyStockPALocQty     
       
                    IF @n_SkuQtyRemaining < @n_SafetyStockPAQty    
                    BEGIN  
                    IF @n_SkuQtyRemaining > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    END                                
                    ELSE   
                    BEGIN  
                    IF @n_SafetyStockPAQty > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SafetyStockPAQty         
                    END     
                 END                            
    
                 IF @b_debug = 1    
                 BEGIN    
                    PRINT 'Find Same pickzone of same itemclass @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END                     
              END    
                  
              --Find pickzone has most empty loc    
              IF @c_SuggestLoc = ''    
              BEGIN                     
                 SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0    
    
                 SELECT TOP 1 @n_RowID = RowID,    
                        @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                      WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                      WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                      WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                      WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                      WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                 ELSE 0 END,    
                        @c_SafetyStockPALoc = TPA.Loc,  
                        @c_SafetyStockPALocZone = TPA.PickZone  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup   
                 AND TPA.PickZone = CASE WHEN @c_SafetyStockPALocZone = '' THEN @c_MostEmptyLocPickZone ELSE @c_SafetyStockPALocZone END --JS   
                 --AND TPA.Pickzone = @c_MostEmptyLocPickZone                                     
                 AND TPA.Qty = 0    
                 ORDER BY ABS(TPA.Score - @n_SafetyStockPALocScore),TPA.LogicalLocation, TPA.Loc          --JS sort by score to found near loc  
                                     
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    
  
               --JS some time @n_SkuQtyRemaining more then @n_SafetyStockPALocQty and @n_SafetyStockPALocQty   
               --IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                    --   SET @n_SuggestQty = @n_SkuQtyRemaining    
                    --ELSE       
                    --   SET @n_SuggestQty = @n_SafetyStockPALocQty     
       
                    IF @n_SkuQtyRemaining < @n_SafetyStockPAQty    
                    BEGIN  
                    IF @n_SkuQtyRemaining > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    END  
                    ELSE   
                    BEGIN  
                    IF @n_SafetyStockPAQty > @n_SafetyStockPALocQty  
                       SET @n_SuggestQty = @n_SafetyStockPALocQty    
                    ELSE  
                       SET @n_SuggestQty = @n_SafetyStockPAQty         
                    END     
                 END                  
                              
                 IF @b_debug = 1    
                 BEGIN    
                     PRINT 'Find pickzone has most empty loc @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END                                      
              END               
                  
              --If found loc, increase safetystock balance    
              IF @c_SuggestLoc <> ''    
              BEGIN    
                IF @c_ASNType = 'CASE' --By UCC  
                BEGIN  
                   SET @n_TotalPieceQtyTake = 0  
                   SET @n_TotalCaseQtyTake = 0  
                     
                   SELECT @n_TotalPieceQtyTake = SUM(TotalPiece) --Get piece qty first  
                   FROM #TMP_SKUQTYSUMM  
                   WHERE Storerkey = @c_Storerkey  
                   AND Sku = @c_Sku  
                     
                   IF @n_TotalPieceQtyTake >= @n_SuggestQty  
                   BEGIN  
                     SET @n_TotalPieceQtyTake = @n_SuggestQty  
                   END  
                   ELSE  
                   BEGIN  
                     WHILE (@n_TotalPieceQtyTake + @n_TotalCaseQtyTake) < @n_SuggestQty  --if piece qty not enouth, get UCC and break carton  
                     BEGIN                          
                        SELECT TOP 1 @c_UCCNo = UCCNo, @n_UCCQty = Qty  
                        FROM #TMP_UCC  
                        WHERE Storerkey = @c_Storerkey  
                        AND Sku = @c_Sku  
                        --AND Qty <= @n_SuggestQty - (@n_TotalPieceQtyTake + @n_TotalCaseQtyTake)   --JS just choose ucc no need check qty  
                        AND SuggestLoc = ''                         
                        ORDER BY Qty DESC  
                          
                        IF @@ROWCOUNT = 0  
                          BREAK  
                          
                        UPDATE #TMP_UCC   
                        SET SuggestLoc = 'BREAKUCC'  
                        WHERE UCCNo = @c_UCCNo   
                          
                        UPDATE #TMP_SKUQTYSUMM   
                        SET TotalCase = TotalCase - 1,  
                       TotalPiece = TotalPiece + CaseCnt  --JS added totalpiece qty, since safetystock sometime will not use all UCC QTY  
                        WHERE Storerkey = @c_Storerkey  
                        AND Sku = @c_Sku  
                        AND CaseCnt = @n_UCCQty  
                          
                        SET @n_TotalCaseQtyTake = @n_TotalCaseQtyTake + @n_UCCQty  
                     END  
                   END                       
                     
                   SET @n_TotalPieceQtyTake = @n_TotalPieceQtyTake + @n_TotalCaseQtyTake  
                   --Update piece qty to sku PA qty summary  
                   IF @n_TotalPieceQtyTake >= @n_SuggestQty  
                   BEGIN  
                     SET @n_TotalPieceQtyTake = @n_SuggestQty  
                   END  
                     
                   SET @n_RowID_SkuQtySumm = 0   --not use @n_RowID, shoud @n_RowID_SkuQtySumm  
                   SET @n_RemainTotalPieceQtyTake =  @n_TotalPieceQtyTake  
                   WHILE @n_RemainTotalPieceQtyTake > 0  
                   BEGIN  
                     SELECT TOP 1 @n_RowID_SkuQtySumm = RowID,  --JS not use @n_RowID, shoud @n_RowID_SkuQtySumm  
                                  @n_TotalPiece = TotalPiece  
                     FROM #TMP_SKUQTYSUMM  
                     WHERE Storerkey = @c_Storerkey  
                     AND Sku = @c_Sku  
                     AND TotalPiece > 0  
                     AND RowID > @n_RowID_SkuQtySumm   --JS not use @n_RowID, shoud @n_RowID_SkuQtySumm  
                     ORDER BY RowID  
                       
                     IF @@ROWCOUNT = 0  
                        BREAK  
                       
                     IF @n_TotalPiece > @n_RemainTotalPieceQtyTake           
                        SET @n_TotalPiece = @n_RemainTotalPieceQtyTake      
                                               
                     UPDATE #TMP_SKUQTYSUMM  
                     SET TotalPiece = TotalPiece - @n_TotalPiece  
                     WHERE RowID = @n_RowID_SkuQtySumm   --JS not use @n_RowID, shoud @n_RowID_SkuQtySumm  
                       
                     SET @n_RemainTotalPieceQtyTake = @n_RemainTotalPieceQtyTake - @n_TotalPiece                       
                   END                                                        
                END  
                  
                 --SET @n_SuggestQty = @n_TotalPieceQtyTake + @n_TotalCaseQtyTake   --JS suggestqty no need change                                                      
                SET @n_SafetyStockSum = @n_SafetyStockSum + @n_SuggestQty                        
              END       
           END                                                        
         END    
         */ 

         ---Highbay stock PA    
         IF @n_continue IN(1,2) AND @c_SuggestLoc = ''    
         BEGIN    
            SELECT @c_HBStockPALoc = '', @n_HBStockPALocQty = 0, @n_RowID = 0, @n_HB_PACarton = 0,  @n_FP_CartonCnt = 0, @n_HP_CartonCnt = 0, @n_RowID_SkuQtySumm = 0  
              
            IF @c_ASNType = 'CASE'  
            BEGIN  
              SELECT TOP 1 @n_RowID_SkuQtySumm = RowID,  
                           @n_CaseCnt = CaseCnt,  
                           @n_HB_PACarton = TotalCase  
              FROM #TMP_SKUQTYSUMM  
              WHERE Storerkey = @c_Storerkey  
              AND Sku = @c_Sku  
              AND TotalCase > 0  
              ORDER BY TotalCase DESC  
            END  
            ELSE  
            BEGIN  
               SELECT @n_HB_PACarton = FLOOR(@n_SkuQtyRemaining / @n_CaseCnt)                
            END  
                
            --IF @n_CaseCnt > 0    
               --SELECT @n_HB_PACarton = FLOOR(@n_SkuQtyRemaining / @n_CaseCnt)                
                   
            IF @b_debug = 1     
            BEGIN    
               PRINT '2---HIGHBAY PA '    
               PRINT '@n_HB_PACarton=' + CAST(@n_HB_PACarton AS NVARCHAR)    
            END                   
                   
            IF @n_HB_PACarton > 0    
            BEGIN                               
               --Find HB Full pallet(FP) loc     
               IF @c_SuggestLoc = ''                   
               BEGIN    
                  SELECT TOP 1 @n_RowID = RowID,    
                               @c_HBStockPALoc = TPA.Loc,  
                               @n_FP_CartonCnt = TPA.FP_CartonCnt,  
                               @n_HP_CartonCnt = TPA.HP_CartonCnt  
                  FROM #TMP_PALOC TPA    
                  WHERE TPA.LocationRoom = 'HIGHBAY'    
                  AND TPA.Qty = 0    
                  AND TPA.LocationCategory = 'FP'    
                  AND TPA.HP_CartonCnt <= CASE WHEN @c_ASNType = 'CASE' THEN TPA.HP_CartonCnt ELSE @n_HB_PACarton END   ----JS02 add case logic, if case(UCC), direct PA to FP loc
                  AND TPA.FP_CartonCnt > 0       
                  ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc               
                    
                  IF @c_HBStockPALoc <> ''  
                  BEGIN
                     IF @c_ASNType = 'CASE' ----JS02 add case logic, if case(UCC), direct PA to FP loc
                     BEGIN
                        SET @n_HBStockPALocQty = @n_HB_PACarton
                     END
                     ELSE
                     BEGIN
                        --SELECT @n_HBStockPALocQty = FLOOR(@n_HB_PACarton / @n_HP_CartonCnt)   
                        SELECT @n_HBStockPALocQty = FLOOR(@n_HB_PACarton / @n_FP_CartonCnt) * @n_FP_CartonCnt  --JS shoube be max multi FP*max HP Cartcnt  
                      
                        IF (@n_HB_PACarton - @n_HBStockPALocQty) >= @n_HP_CartonCnt  
                        BEGIN  
                           --SET @n_HBStockPALocQty = @n_HBStockPALocQty + @n_HP_CartonCnt  --JS should be all max FP + min FP  --JS ver 1.1   
                           SET @n_HBStockPALocQty = @n_HB_PACarton  --JS ver 1.1 left qty more than HP, should be @n_HBStockPALocQty + (@n_HB_PACarton - @n_HBStockPALocQty), then = @n_HB_PACarton  
                        END  
                     END
                  END

                  IF @n_HBStockPALocQty > 0    
                  BEGIN                   
                     SET @c_SuggestLoc = @c_HBStockPALoc                     
                     SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                     SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  END                                             
                    
                  /*SELECT TOP 1 @n_RowID = RowID,    
                        @n_HBStockPALocQty = CASE WHEN TPA.FP_CartonCnt <= @n_HB_PACarton THEN    
                                                  TPA.FP_CartonCnt    
                                             ELSE @n_HB_PACarton END,                                                   
                        @c_HBStockPALoc = TPA.Loc              
                  FROM #TMP_PALOC TPA    
                  WHERE TPA.LocationRoom = 'HIGHBAY'    
                  AND TPA.Qty = 0    
                  AND TPA.LocationCategory = 'FP'    
                  AND TPA.HP_CartonCnt <= @n_HB_PACarton    
                  AND TPA.FP_CartonCnt > 0       
                  ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc                            
                      
                  IF @n_HBStockPALocQty > 0    
                  BEGIN                   
                     SET @c_SuggestLoc = @c_HBStockPALoc                     
                     SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                     SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  END*/                                              
                      
                  IF @b_debug = 1    
                  BEGIN    
                      PRINT 'Find HB Full pallet(FP) loc  @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                  END                                      
               END                  
              

			  --JS02 remove HP and FC logic, only need FP for all full case
			   /*
               --Find HB Half pallet(HP) loc     
               IF @c_SuggestLoc = ''                   
               BEGIN    
                  SELECT @c_HBStockPALoc = '', @n_HBStockPALocQty = 0, @n_FP_CartonCnt = 0, @n_HP_CartonCnt = 0    
                    
                  SELECT TOP 1 @n_RowID = RowID,    
                               @c_HBStockPALoc = TPA.Loc,  
                               @n_FP_CartonCnt = TPA.FP_CartonCnt,  
                               @n_HP_CartonCnt = TPA.HP_CartonCnt  
                  FROM #TMP_PALOC TPA    
                  WHERE TPA.LocationRoom = 'HIGHBAY'    
                  AND TPA.Qty = 0    
                  AND TPA.LocationCategory = 'HP'    
                  AND TPA.HP_CartonCnt <= @n_HB_PACarton    
                  AND TPA.FP_CartonCnt > 0       
                  ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc               
                    
                  IF @c_HBStockPALoc <> ''  
                  BEGIN  
                     --SELECT @n_HBStockPALocQty = FLOOR(@n_HB_PACarton / @n_HP_CartonCnt)   
                     SELECT @n_HBStockPALocQty = FLOOR(@n_HB_PACarton / @n_FP_CartonCnt) * @n_FP_CartonCnt  --JS shoube be max multi HP*max FP Cartoncnt  
             
                     IF (@n_HB_PACarton - @n_HBStockPALocQty) >= @n_HP_CartonCnt  
                     BEGIN   
                        --SET @n_HBStockPALocQty = @n_HBStockPALocQty + @n_HP_CartonCnt  --JS should be all max HP + min HP  --JS ver 1.1  
                        SET @n_HBStockPALocQty = @n_HB_PACarton  --JS ver 1.1 left qty more than HP, should be @n_HBStockPALocQty + (@n_HB_PACarton - @n_HBStockPALocQty), then = @n_HB_PACarton    
                     END  
                  END                                      
                      
                  IF @n_HBStockPALocQty > 0    
                  BEGIN                   
                     SET @c_SuggestLoc = @c_HBStockPALoc                     
                     SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                     SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  END                                             
                                                         
                  --SELECT TOP 1 @n_RowID = RowID,    
                  --      --@n_HBStockPALocQty = TPA.HP_CartonCnt,                    
                  --      @n_HBStockPALocQty = CASE WHEN TPA.FP_CartonCnt <= @n_HB_PACarton THEN    
                  --                                TPA.FP_CartonCnt    
                  --                           ELSE @n_HB_PACarton END,  --JS should be use case when since if no found loc in FP  
                  --      @c_HBStockPALoc = TPA.Loc                                  
                  --FROM #TMP_PALOC TPA    
                  --WHERE TPA.LocationRoom = 'HIGHBAY'    
                  --AND TPA.Qty = 0    
                  --AND TPA.LocationCategory = 'HP'    
                  --AND TPA.HP_CartonCnt <= @n_HB_PACarton    
                  --AND TPA.HP_CartonCnt > 0    
                  --ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc                            
                      
                  --IF @n_HBStockPALocQty > 0    
                  --BEGIN                   
                  --   SET @c_SuggestLoc = @c_HBStockPALoc                     
                  --   SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                  --   SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  --END                                 
                      
                  IF @b_debug = 1    
                  BEGIN    
                      PRINT 'Find HB Half pallet(HP) loc @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                  END                                                       
               END                                               
    
               --Find HB Full case(FC) loc with same sku    
               --IF @c_SuggestLoc = ''                   
               --BEGIN    
               --   SELECT @c_HBStockPALoc = '', @n_HBStockPALocQty = 0    
                     
               --   SELECT TOP 1 @n_RowID = RowID,    
               --         @n_HBStockPALocQty = CASE WHEN TPA.FP_CartonCnt - CEILING(TPA.Qty / @n_CaseCnt) <= @n_HB_PACarton THEN    
               --                                        TPA.FP_CartonCnt - CEILING(TPA.Qty / @n_CaseCnt)    
               --                                   ELSE @n_HB_PACarton END,    
               --         @c_HBStockPALoc = TPA.Loc                                  
               --   FROM #TMP_PALOC TPA    
               --   WHERE TPA.LocationRoom = 'HIGHBAY'    
               --   AND TPA.FP_CartonCnt - CEILING(TPA.Qty / @n_CaseCnt) > 0                                      
               --   AND TPA.LocationCategory = 'FC'    
               --   AND TPA.FP_CartonCnt > 0    
               --   AND TPA.Sku = @c_Sku    
               --   ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc                            
                      
               --   IF @n_HBStockPALocQty > 0    
               --   BEGIN                   
               --      SET @c_SuggestLoc = @c_HBStockPALoc                     
               --      SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
               --      SET @n_SuggestQty = @n_HBStockPALocQty                                            
               --   END             
                      
               --   IF @b_debug = 1    
               --   BEGIN    
               --       PRINT 'Find HB Full case(FC) loc with same sku  @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
               --   END                                                                        
               --END
                 
               --Find HB Full case(FC) loc with empty    
               IF @c_SuggestLoc = ''                   
               BEGIN    
                  SELECT @c_HBStockPALoc = '', @n_HBStockPALocQty= 0, @n_FP_CartonCnt = 0, @n_HP_CartonCnt = 0      
  
                  SELECT TOP 1 @n_RowID = RowID,    
                               @c_HBStockPALoc = TPA.Loc                                  
                  FROM #TMP_PALOC TPA    
                  WHERE TPA.LocationRoom = 'HIGHBAY'    
                  AND TPA.LocationCategory = 'FC'    
                  --AND TPA.FP_CartonCnt > 0   --JS no need setup max FC since all FC can putaway                  
                  AND TPA.Qty = 0    
                  ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc                            
                 
                  IF @c_HBStockPALoc <> ''  
                     SET @n_HBStockPALocQty = @n_HB_PACarton   
                      
                  IF @n_HBStockPALocQty > 0    
                  BEGIN                   
                     SET @c_SuggestLoc = @c_HBStockPALoc                     
                     SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                     SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  END                              
                                       
                  --SELECT TOP 1 @n_RowID = RowID,    
                  --      @n_HBStockPALocQty = CASE WHEN TPA.FP_CartonCnt <= @n_HB_PACarton THEN    
                  --                                     TPA.FP_CartonCnt     
                  --                           ELSE @n_HB_PACarton END,    
                  --      @c_HBStockPALoc = TPA.Loc                                  
                  --FROM #TMP_PALOC TPA    
                  --WHERE TPA.LocationRoom = 'HIGHBAY'    
                  --AND TPA.LocationCategory = 'FC'    
                  --AND TPA.FP_CartonCnt > 0                     
                  --AND TPA.Qty = 0    
                  --ORDER BY TPA.Priority, TPA.LogicalLocation, TPA.Loc                            
                      
                  --IF @n_HBStockPALocQty > 0    
                  --BEGIN                   
                  --   SET @c_SuggestLoc = @c_HBStockPALoc                     
                  --   SET @n_HBStockPALocQty = @n_HBStockPALocQty * @n_CaseCnt                     
                  --   SET @n_SuggestQty = @n_HBStockPALocQty                                            
                  --END                                 
                    
                  IF @b_debug = 1    
                  BEGIN    
                      PRINT 'Find HB Full case(FC) loc with empty  @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                  END                                                                        
               END             
               */

               --Update carton assigned PA  
               IF @c_ASNType = 'CASE' AND @c_SuggestLoc <> '' --By UCC  
               BEGIN  
                  SET @n_PACarton = FLOOR(@n_SuggestQty / @n_CaseCnt)      
                    
                  UPDATE #TMP_SKUQTYSUMM  
                  SET Totalcase = TotalCase - @n_PACarton  
                  WHERE RowID = @n_RowID_SkuQtySumm  
  
                  --Update UCC suggest PA Loc  
                  WHILE @n_PACarton > 0  
                  BEGIN                                                                                   
                    SELECT TOP 1 @n_RowID_UCC = RowId  --JS not @n_RowID, should use @n_RowID_UCC  
                    FROM #TMP_UCC                                                                          
                    WHERE Storerkey = @c_Storerkey                                                         
                    AND Sku = @c_Sku                                                                       
                    AND Qty = @n_CaseCnt              
                    AND SuggestLoc = ''                                                                   
                    ORDER BY RowID                                                                   
                                                                                                           
                    IF @@ROWCOUNT = 0                                                                      
                      BREAK                                                                                
                       
                    UPDATE #TMP_UCC  
                    SET SuggestLoc = @c_SuggestLoc  
                    WHERE RowId = @n_RowID_UCC    --JS not @n_RowID, should use @n_RowID_UCC                
    
                    SET @n_PACarton = @n_PACarton - 1                                                                                            
                  END                                                                                                                            
               END             
            END        
         END    
             
         ---SAFETYSTOCK(Original Freeseats) PA 
         IF @n_continue IN(1,2) AND @c_SuggestLoc = ''    
         BEGIN                      
            SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0, @n_RowID = 0    
    
            IF @b_debug = 1     
            BEGIN    
               PRINT '3---SAFETYSTOCK(Original Freeseats) PA '    
            END                   
                
           IF @n_SkuQtyRemaining > 0    
           BEGIN
              --Find same sku    
              IF @c_SuggestLoc = '' 
              BEGIN    
                 SELECT TOP 1 @n_RowID = RowID,    
                        @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                      WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                      WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                      WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                      WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                      WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                      ELSE 0 END - TPA.Qty,    
                        @c_SafetyStockPALoc = TPA.Loc,  
                        @c_SafetyStockPALocZone = TPA.PickZone,    --JS add param  
                        @n_SafetyStockPALocScore = TPA.Score       --JS add param  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup   
                 AND TPA.Qty < CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                    WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                    WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                    WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                    WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                    WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                    ELSE 0 END     
                 AND TPA.PickZone = CASE WHEN @c_SafetyStockPALocZone = '' THEN TPA.PickZone ELSE @c_SafetyStockPALocZone END  --JS02 to keep same pickzone first
				         AND TPA.Sku = @c_Sku
                 ORDER BY TPA.LogicalLocation, TPA.Loc    
                     
                 IF @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0 AND @n_SafetyStockPALocQty > 0    
                 BEGIN    
                    SET @n_SafetyStockPALocQty = FLOOR(@n_SafetyStockPALocQty / @n_PackQtyIndicator) * @n_PackQtyIndicator     
                 END    
                      
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    

                    IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    ELSE       
                       SET @n_SuggestQty = @n_SafetyStockPALocQty         
                 END      
                     
                 IF @b_debug = 1    
                 BEGIN    
                     PRINT 'Find Same Sku @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END    
              END  
			  
			        --Find same pickzone of same SKU    
              IF @c_SuggestLoc = ''    
              BEGIN                     
                 SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0    
                     
                 SELECT TOP 1 @n_RowID = RowID,    
                       @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                     WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                     WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                     WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                     WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                     WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                     ELSE 0 END,    
                       @c_SafetyStockPALoc = TPA.Loc,  
                       @c_SafetyStockPALocZone = TPA.PickZone,
                       @n_SafetyStockPALocScore = TPA.Score
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup 
                 AND TPA.PickZone IN (SELECT DISTINCT T.Pickzone     
                                      FROM #TMP_PALOC T     
                                      WHERE T.SKU = @c_Sku    
                                      AND T.Qty > 0)    
                 AND TPA.Qty = 0    
                 ORDER BY (CASE WHEN TPA.PickZone = @c_SafetyStockPALocZone THEN 1 ELSE 2 END), TPA.PickZone, ABS(TPA.Score - @n_SafetyStockPALocScore), TPA.LogicalLocation, TPA.Loc 
                                     
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    

                    IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    ELSE       
                       SET @n_SuggestQty = @n_SafetyStockPALocQty       
                 END   
    
                 IF @b_debug = 1    
                 BEGIN    
                    PRINT 'Find Same pickzone of same itemclass @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END                     
              END    
                  
              --Find same pickzone of same itemclass    
              IF @c_SuggestLoc = ''    
              BEGIN                     
                 SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0    
                     
                 SELECT TOP 1 @n_RowID = RowID,    
                       @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                     WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                     WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                     WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                     WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                     WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                     ELSE 0 END,    
                       @c_SafetyStockPALoc = TPA.Loc,  
                       --@c_SafetyStockPALocZone = TPA.PickZone,   ---JS add param 
                       @n_SafetyStockPALocScore = TPA.Score ---JS add param  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup     
                 AND TPA.PickZone IN (SELECT DISTINCT T.Pickzone     
                                      FROM #TMP_PALOC T     
                                      WHERE T.ItemClass = @c_ItemClass    
                                      AND T.Qty > 0)    
                 --AND TPA.PickZone = CASE WHEN @c_SafetyStockPALocZone = '' THEN TPA.PickZone ELSE @c_SafetyStockPALocZone END --JS --JS02 one sku can put to multi Zone, remove @c_SafetyStockPALocZone logic
                 AND TPA.Qty = 0    
                 ORDER BY TPA.PickZone, ABS(TPA.Score - @n_SafetyStockPALocScore), TPA.LogicalLocation, TPA.Loc  --JS add order ABS score  --JS02 one sku can put to multi Zone, remove @c_SafetyStockPALocZone logic, add orderby PickZone
                                     
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    

                    IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    ELSE       
                       SET @n_SuggestQty = @n_SafetyStockPALocQty       
                 END                            
    
                 IF @b_debug = 1    
                 BEGIN    
                    PRINT 'Find Same pickzone of same itemclass @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END                     
              END    
                  
              --Find pickzone has most empty loc    
              IF @c_SuggestLoc = ''    
              BEGIN                     
                 SELECT @c_SafetyStockPALoc = '', @n_SafetyStockPALocQty = 0    
    
                 SELECT TOP 1 @n_RowID = RowID,    
                        @n_SafetyStockPALocQty = CASE WHEN TPA.LocationCategory = 'MezzanineB' THEN @n_MezzanineB     
                                                      WHEN TPA.LocationCategory = 'MezzanineS' THEN @n_MezzanineS     
                                                      WHEN TPA.LocationCategory = 'MezzanineM' THEN @n_MezzanineM     
                                                      WHEN TPA.LocationCategory = 'MezzanineX' THEN @n_MezzanineX     
                                                      WHEN TPA.LocationCategory = 'MezzanineY' THEN @n_MezzanineY     
                                                      WHEN TPA.LocationCategory = 'MezzanineZ' THEN @n_MezzanineZ     
                                                 ELSE 0 END,    
                        @c_SafetyStockPALoc = TPA.Loc  
                        --@c_SafetyStockPALocZone = TPA.PickZone  
                 FROM #TMP_PALOC TPA    
                 WHERE TPA.LocationRoom = 'SAFETYSTOCK' AND TPA.PutawayZone = @c_SkuGroup    --JS Add  TPA.PutawayZone = @c_SkuGroup   
                 --AND TPA.Pickzone = @c_MostEmptyLocPickZone          --JS Add order by to find most empty                              
                 AND TPA.Qty = 0    
                 ORDER BY CASE WHEN TPA.PickZone = @c_MostEmptyLocPickZone THEN 1 ELSE 2 END, TPA.PickZone, ABS(TPA.Score - @n_SafetyStockPALocScore), TPA.LogicalLocation, TPA.Loc          --JS sort by score to found near loc  
                                     
                 IF @n_SafetyStockPALocQty > 0    
                 BEGIN                   
                    SET @c_SuggestLoc = @c_SafetyStockPALoc    

                    IF @n_SkuQtyRemaining < @n_SafetyStockPALocQty    
                       SET @n_SuggestQty = @n_SkuQtyRemaining    
                    ELSE       
                       SET @n_SuggestQty = @n_SafetyStockPALocQty        
                 END                  
                              
                 IF @b_debug = 1    
                 BEGIN    
                     PRINT 'Find pickzone has most empty loc @c_SuggestLoc=' +@c_SuggestLoc + ' @n_SuggestQty=' + CAST(@n_SuggestQty AS NVARCHAR)                      
                 END                                      
              END                                                                          
           END             
             
           --Update SKU PA Qty summary  
           IF @c_ASNType = 'CASE' AND @c_SuggestLoc <> ''  --By UCC  
           BEGIN                  
              SET @n_RowID_SkuQtySumm = 0  --JS not use @n_RowID, shoud @n_RowID_SkuQtySumm  
              SET @n_TotalPiece = 0  
              SET @n_RemainTotalPieceQtyTake = @n_SuggestQty  
              
              WHILE @n_RemainTotalPieceQtyTake > 0                                                          
              BEGIN                                                                                         
                SELECT TOP 1 @n_RowID_SkuQtySumm = RowID,                                                             
                            @n_TotalPiece = TotalPiece                                                     
                FROM #TMP_SKUQTYSUMM                                                                       
                WHERE Storerkey = @c_Storerkey                                                             
                AND Sku = @c_Sku                                                                           
                AND TotalPiece > 0                                                                         
                AND RowID > @n_RowID_SkuQtySumm  --Js not use @n_RowID, shoud @n_RowID_SkuQtySumm                                                                     
                ORDER BY RowID                                                                             
                                                                                                           
                IF @@ROWCOUNT = 0                                                                          
                   BREAK                                                                                   
                                                                                                           
                if @n_TotalPiece > @n_RemainTotalPieceQtyTake                                              
                   SET @n_TotalPiece = @n_RemainTotalPieceQtyTake                                          
                                                                                                          
                UPDATE #TMP_SKUQTYSUMM                                                                     
                SET TotalPiece = TotalPiece - @n_TotalPiece                                                
                WHERE RowID = @n_RowID_SkuQtySumm  --JS not use @n_RowID, shoud @n_RowID_SkuQtySumm                                                                    
                                                                                                           
                SET @n_RemainTotalPieceQtyTake = @n_RemainTotalPieceQtyTake - @n_TotalPiece                
             END                                                                                           
           END                                                        
         END             
                      
         IF @c_SuggestLoc = ''    
         BEGIN                
            SET @n_Continue = 3    
            SET @n_Err = 63030    
            SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': No Suggest PA Loc Found'     
                          + '. (ispBatPA04)'     
                
            IF @b_debug = 1    
              PRINT @c_ErrMsg                  
                              
            GOTO QUIT_SP                
         END                     
  
         --Update UCC  
         IF @c_ASNType = 'CASE' --By UCC  
         BEGIN  
            DECLARE CUR_UCCUPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT DISTINCT UCCNo, SuggestLoc  
               FROM #TMP_UCC  
               WHERE Storerkey = @c_Storerkey  
               AND Sku = @c_Sku  
               AND SuggestLoc <> ''  
  
            OPEN CUR_UCCUPD                                              
                                                                         
            FETCH NEXT FROM CUR_UCCUPD INTO @c_UCCNo, @c_ToLoc  
                                                                         
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)           
            BEGIN  
              UPDATE UCC   
              SET Userdefined10 = @c_ToLoc,  
                  TrafficCop = NULL  
              WHERE UCCNo = @c_UccNo  
                
               FETCH NEXT FROM CUR_UCCUPD INTO @c_UCCNo, @c_ToLoc  
            END  
            CLOSE CUR_UCCUPD  
            DEALLOCATE CUR_UCCUPD     
     
  
            --JS Added loic for case type locked loc  
            DECLARE CUR_LOCUPD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
               SELECT DISTINCT SuggestLoc  
               FROM #TMP_UCC  
               WHERE Storerkey = @c_Storerkey  
               AND Sku = @c_Sku  
               AND SuggestLoc <> ''  
            
            OPEN CUR_LOCUPD                                              
                                                                         
            FETCH NEXT FROM CUR_LOCUPD INTO @c_ToLoc  
                                                                         
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)           
            BEGIN  
              UPDATE LOC   
              SET LocationHandling = 'INUSE',  
                  TrafficCop = NULL  
              WHERE Loc = @c_ToLoc  
                
               FETCH NEXT FROM CUR_LOCUPD INTO @c_ToLoc  
            END  
            CLOSE CUR_LOCUPD  
            DEALLOCATE CUR_LOCUPD   
         END  --end update ucc
                     
         SET @n_PAToLocQty = @n_SuggestQty    
             
         UPDATE #TMP_PALOC SET Qty = Qty + @n_SuggestQty WHERE RowID = @n_RowID    
         
         SET @n_SkuQtyRemaining = @n_SkuQtyRemaining - @n_PAToLocQty    
           
         IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE Loc = @c_SuggestLoc AND LocationRoom  = 'HIGHBAY') --if highbay skip RFPUTAWAY  
            AND @c_ASNType = 'CASE'  
            GOTO NEXT_LOC  
              
         WHILE @n_PAToLocQty > 0    
         BEGIN       
            SELECT TOP 1    
                     @c_CurrReceiptkey = RD.Receiptkey     
                  ,  @c_ReceiptLineNumber = RD.ReceiptLineNumber    
                  ,  @c_FromLoc     = RD.ToLoc    
                  ,  @c_FromID      = RD.ToID     
                  ,  @c_ToID        = CASE WHEN ISNULL(LOC.LoseId,'') = '1' THEN '' ELSE RD.ToID END           
                  ,  @n_QtyReceived = CASE WHEN @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0 THEN      
                                         FLOOR((CASE WHEN RD.Beforereceivedqty > 0 THEN RD.Beforereceivedqty ELSE RD.QtyExpected END - @n_LinePAQty) / @n_PackQtyIndicator) * @n_PackQtyIndicator    
                                      ELSE    
                                         CASE WHEN RD.Beforereceivedqty > 0 THEN RD.Beforereceivedqty ELSE RD.QtyExpected END - @n_LinePAQty    
                                      END - ISNULL(UCC.Qty,0)   --exclude ucc qty for highbay due to skip RFPUTAWAY       
                  ,  @n_ReceiptUCCQTY = ISNULL(UCC.Qty,0)         
                  ,  @c_lottable01 = R.ExternReceiptkey                     
                  ,  @c_lottable02 = RD.Lottable02                          
                  ,  @c_lottable03 = RD.Lottable03                          
                  ,  @d_lottable04 = RD.Lottable04                          
                  ,  @d_lottable05 = RD.Lottable05                          
                  ,  @c_lottable06 = RD.Lottable06                          
                  ,  @c_lottable07 = RD.Lottable07                          
                  ,  @c_lottable08 = RD.Lottable08                          
                  ,  @c_lottable09 = RD.Lottable09                          
                  ,  @c_lottable10 = RD.Lottable10                          
                  ,  @c_lottable11 = RD.Lottable11                          
                  ,  @c_lottable12 = RD.Lottable12                          
                  ,  @d_lottable13 = RD.Lottable13                          
                  ,  @d_lottable14 = RD.Lottable14                          
                  ,  @d_lottable15 = RD.Lottable15                          
            FROM RECEIPTDETAIL RD (NOLOCK)    
            JOIN RECEIPT R (NOLOCK) ON RD.Receiptkey = R.Receiptkey    
            CROSS APPLY (SELECT SUM(CASE WHEN RD1.Beforereceivedqty > 0 THEN RD1.Beforereceivedqty ELSE RD1.QtyExpected END) AS RQty  --total pallet qty of the sku    
                         FROM RECEIPTDETAIL RD1 (NOLOCK)    
                         WHERE RD1.Storerkey = RD.Storerkey    
                         AND RD1.Sku = RD.Sku    
                         AND RD1.ToID = RD.ToID    
                         AND RD1.ToLoc = RD.ToLoc    
                         AND RD1.Receiptkey = RD.Receiptkey    
                         AND RD1.ReceiptLineNumber = RD.ReceiptLineNumber     
                         ) AS PLTTOT    
            OUTER APPLY (SELECT SUM(Qty) AS Qty FROM UCC (NOLOCK) WHERE UCC.Storerkey = RD.Storerkey AND UCC.Sku = RD.Sku  
                              AND UCC.Externkey = RD.ExternReceiptkey  
                              AND UCC.Userdefined08 = RD.Userdefine03  
                              AND UCC.Userdefined09 = RD.Userdefine04  
                              AND UCC.Userdefined10 NOT IN('MIXSKU','BREAKUCC')  
                              AND @c_ASNType = 'CASE') AS UCC   --mix sku ucc or ucc breaked need to consider as loose qty            
            LEFT JOIN LOC (NOLOCK) ON RD.ToLoc = LOC.Loc      
            WHERE RD.ReceiptKey IN (SELECT ColValue FROM dbo.fnc_DelimSplit(',', @c_ReceiptKey))    
            AND   RD.Storerkey = @c_Storerkey    
            AND   RD.Sku = @c_Sku    
            AND   (RD.QtyExpected > 0 OR RD.Beforereceivedqty > 0)    
            AND (ISNULL(RD.UserDefine10,'') = ''     
                OR (ISNULL(RD.UserDefine10,'') = CONVERT(NVARCHAR(20), @n_PABookingKey))     
                 )     
            AND   RD.Receiptkey+RD.ReceiptLineNumber > @c_CurrReceiptkey+@c_ReceiptLineNumber              
            --AND RD.Lottable02 = @c_RDLottable02      
            AND NOT EXISTS(SELECT 1     
                           FROM RFPutaway RPA (NOLOCK)    
                           JOIN LOTATTRIBUTE LA (NOLOCK) ON RPA.Lot = LA.Lot    
                           WHERE RPA.Storerkey = RD.Storerkey     
                           AND RPA.Sku = RD.Sku    
                           AND RPA.FromLoc = RD.ToLoc    
                           AND RPA.FromID = RD.ToID    
                           AND RPA.PABookingKey = RD.Userdefine10    
                           AND RPA.Receiptkey = RD.Receiptkey       
                           AND RPA.ReceiptLineNumber = RD.ReceiptLineNumber     
                           HAVING SUM(RPA.Qty) >= (PLTTOT.RQty - ISNULL(UCC.Qty,0)))  --make sure the receiptline not fully PA yet             
            AND NOT EXISTS(SELECT 1    
                           FROM RECEIPTDETAIL RD2 (NOLOCK)    
                           WHERE RD2.Receiptkey = RD.Receiptkey    
                           AND RD2.Storerkey = RD.Storerkey    
                           AND RD2.Sku = RD.Sku    
                           --AND RD2.Lottable02 = RD.Lottable02    
                           AND RD2.ToLoc = RD.Toloc    
                           AND @c_PrePackIndicator = '2'     
                           AND @n_PackQtyIndicator > 0                  
                           HAVING SUM(CASE WHEN RD2.Beforereceivedqty > 0 THEN RD2.Beforereceivedqty ELSE RD2.QtyExpected END) < @n_PackQtyIndicator    
                          )  --if the sku @n_PackQtyIndicator=2, only putaway the sum receipt line with same lottable02,loc >= @n_PackQtyIndicator    
            AND CASE WHEN @c_PrePackIndicator = '2' AND @n_PackQtyIndicator > 0 THEN     
                   FLOOR((CASE WHEN RD.Beforereceivedqty > 0 THEN RD.Beforereceivedqty ELSE RD.QtyExpected END - @n_LinePAQty) / @n_PackQtyIndicator) --NJOW01    
                ELSE    
                   CASE WHEN RD.Beforereceivedqty > 0 THEN RD.Beforereceivedqty ELSE RD.QtyExpected END - @n_LinePAQty    
                END > 0                                         
            ORDER BY RD.Receiptkey, RD.ReceiptLineNumber                                 
    
            IF @@ROWCOUNT = 0    
            BEGIN    
               BREAK    
            END    
              
            IF @n_QtyReceived < 1  
               GOTO NEXT_LINE  
    
            SET @c_SourceKey = @c_CurrReceiptKey + @c_ReceiptLineNumber    
            SET @c_ReceiptLineUpdate = @c_ReceiptLineNumber                     
            SET @c_ReceiptkeyUpdate = @c_CurrReceiptkey    
                
            IF EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_SuggestLoc AND LoseId = '1')    
               SET @c_ToID = ''    
    
            SET @c_Fromlot = ''     
            SET @b_Success = 1                                               
            EXECUTE nsp_lotlookup                                  
                    @c_Storerkey  = @c_Storerkey                   
                  , @c_sku        = @c_sku                         
                  , @c_lottable01 = @c_Lottable01                  
                  , @c_lottable02 = @c_Lottable02                  
                  , @c_lottable03 = @c_Lottable03                  
                  , @c_lottable04 = @d_Lottable04                  
                  , @c_lottable05 = @d_Lottable05                  
                  , @c_lottable06 = @c_Lottable06                  
                  , @c_lottable07 = @c_Lottable07                  
                  , @c_lottable08 = @c_Lottable08                  
                  , @c_lottable09 = @c_Lottable09                  
                  , @c_lottable10 = @c_Lottable10                  
                  , @c_lottable11 = @c_Lottable11                  
                  , @c_lottable12 = @c_Lottable12                  
                  , @c_lottable13 = @d_Lottable13                  
                  , @c_lottable14 = @d_Lottable14                  
                  , @c_lottable15 = @d_Lottable15                  
                  , @c_Lot        = @c_FromLot  OUTPUT             
                  , @b_Success    = @b_Success  OUTPUT             
                  , @n_err        = @n_err      OUTPUT             
                  , @c_ErrMsg     = @c_ErrMsg   OUTPUT             
    
            IF @b_Success <> 1    
            BEGIN    
               SET @n_Continue = 3    
               SET @n_Err = 63070    
               SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Executing nsp_lotlookup. '     
               GOTO QUIT_SP    
            END    
                
            IF ISNULL(@c_Fromlot,'') = ''     
            BEGIN    
              IF EXISTS(SELECT 1 FROM SKU (NOLOCK)     
                        WHERE Storerkey = @c_Storerkey     
                        AND Sku = @c_Sku    
                        AND Lottable05Label = 'RCP_DATE')                                                   
               BEGIN     
                  SELECT @d_Lottable05 = CONVERT(DATETIME, CONVERT(CHAR(20), GETDATE(), 112))     
               END       
                                  
               EXECUTE nsp_lotgen    
                              @c_storerkey    
                            , @c_sku    
                            , @c_lottable01    
                            , @c_lottable02    
                            , @c_lottable03    
                            , @d_lottable04    
                            , @d_lottable05    
                            , @c_lottable06      
                            , @c_lottable07      
                            , @c_lottable08      
                            , @c_lottable09      
                            , @c_lottable10      
                            , @c_lottable11      
                            , @c_lottable12      
                            , @d_lottable13      
                            , @d_lottable14      
                            , @d_lottable15      
                            , @c_FromLot   OUTPUT    
                            , @b_Success   OUTPUT    
                            , @n_err       OUTPUT    
                            , @c_ErrMsg    OUTPUT                                                                                     
            END    
    
            IF NOT EXISTS(SELECT 1 FROM LOT (NOLOCK) WHERE Lot = @c_FromLot)    
            BEGIN    
               INSERT INTO LOT (Lot, Storerkey, Sku, Qty)    
               VALUES (@c_FromLot, @c_storerkey, @c_Sku, 0)    
            END     
              
            IF (@n_PAToLocQty < @n_QtyReceived) OR (@n_ReceiptUCCQTY > 0)    --JS Added for check if still have uccqty, not move to next ASN  
            BEGIN    
               SET @n_PAInsertQty = @n_PAToLocQty    
               SET @n_PAToLocQty = 0    
               SET @n_LinePAQty = @n_LinePAQty + @n_PAInsertQty    
               SET @c_CurrReceiptkey = @c_PrevReceiptkey    
               SET @c_ReceiptLineNumber = @c_PrevReceiptLineNumber    
            END    
            ELSE    
            BEGIN    
               SET @n_PAInsertQty = @n_QtyReceived    
               SET @n_PAToLocQty = @n_PAToLocQty - @n_QtyReceived    
               SET @n_LinePAQty = 0    
            END    
    
            IF @n_PAInsertQty > 0    
            BEGIN                             
               IF EXISTS(SELECT 1 FROM RFPUTAWAY (NOLOCK)     
                         WHERE Storerkey = @c_Storerkey    
                         AND Sku = @c_Sku    
                         AND Lot = @c_FromLot    
                         AND FromLoc = @c_FromLoc    
                         AND FromID = @c_FromID    
                         AND SuggestedLoc = @c_SuggestLoc    
                         AND ID = @c_ToID    
                         AND PAbookingkey = @n_PABookingKey                                
                         AND Receiptkey = @c_ReceiptKeyUpdate      
                         AND ReceiptLineNumber = @c_ReceiptLineUpdate)                               
               BEGIN    
                 UPDATE RFPUTAWAY WITH (ROWLOCK)    
                 SET Qty = Qty + @n_PAInsertQty    
                 WHERE Storerkey = @c_Storerkey    
                       AND Sku = @c_Sku    
                       AND Lot = @c_FromLot    
                       AND FromLoc = @c_FromLoc    
                       AND FromID = @c_FromID    
                       AND SuggestedLoc = @c_SuggestLoc    
                       AND ID = @c_ToID    
                       AND PAbookingkey = @n_PABookingKey    
                       AND Receiptkey = @c_ReceiptKeyUpdate      
                       AND ReceiptLineNumber = @c_ReceiptLineUpdate     
               END    
               ELSE    
               BEGIN      
                  INSERT INTO dbo.RFPutaway (Storerkey, SKU, LOT, FromLOC, FromID, SuggestedLOC, ID, ptcid, QTY, CaseID, TaskDetailKey, Func, PABookingKey, Receiptkey, ReceiptLineNumber, UDF03) --NJOW01  --JS added UDF03  
                  VALUES (@c_Storerkey, @c_Sku, @c_FromLot, @c_FromLoc, @c_FromID, @c_SuggestLoc, @c_ToID, @c_UserName, @n_PAInsertQty, '', '', 0, @n_PABookingKey, @c_ReceiptKeyUpdate, @c_ReceiptLineUpdate, @n_CaseCnt)    
               END    
                   
               IF @n_PABookingKey = 0 --renew every sku + lottable02    
               BEGIN    
                  SET @n_PABookingKey = SCOPE_IDENTITY()    
                      
                  UPDATE dbo.RFPutaway     
                  SET PABookingKey = @n_PABookingKey    
                  WHERE RowRef = @n_PABookingKey    
               END    
                   
               IF ISNULL(@c_ToID,'') <> ''    
               BEGIN    
                  IF NOT EXISTS( SELECT 1 FROM dbo.ID WITH (NOLOCK) WHERE ID = @c_ToID)    
                  BEGIN    
                     INSERT INTO ID (ID) VALUES (@c_ToID)    
                  END    
               END    
                   
               IF EXISTS (SELECT 1     
                          FROM dbo.LOTxLOCxID WITH (NOLOCK)    
                          WHERE LOT = @c_FromLot    
                          AND LOC = @c_SuggestLoc    
                          AND ID = @c_ToID)    
               BEGIN    
                  UPDATE dbo.LOTxLOCxID WITH (ROWLOCK) SET     
                     PendingMoveIn = PendingMoveIn + @n_PAInsertQty     
                  WHERE LOT = @c_FromLot    
                  AND LOC = @c_SuggestLoc    
                  AND ID  = @c_ToID    
               END    
               ELSE    
               BEGIN    
                  INSERT dbo.LOTxLOCxID (LOT, LOC, ID, Storerkey, SKU, PendingMoveIn)    
                  VALUES (@c_FromLot, @c_SuggestLoc, @c_ToID, @c_Storerkey, @c_Sku, @n_PAInsertQty)    
               END    
                        
               IF EXISTS ( SELECT 1    
                           FROM RECEIPTDETAIL WITH (NOLOCK)    
                           WHERE ReceiptKey = @c_ReceiptKeyUpdate    
                           AND ReceiptLineNumber = @c_ReceiptLineUpdate    
                           AND (UserDefine10 = '' OR UserDefine10 IS NULL)     
                         )    
             BEGIN    
                  UPDATE RECEIPTDETAIL     
                  SET RECEIPTDETAIL.UserDefine10 = CONVERT(NVARCHAR(20), @n_PABookingKey)    
                     ,RECEIPTDETAIL.Lottable05 = @d_Lottable05    
                     ,RECEIPTDETAIL.Lottable01 = RECEIPT.ExternReceiptKey     
                     ,RECEIPTDETAIL.EditWho = SUSER_SNAME()    
                     ,RECEIPTDETAIL.EditDate= GETDATE()    
                     ,RECEIPTDETAIL.TrafficCop = NULL    
                  FROM RECEIPTDETAIL    
                  JOIN RECEIPT (NOLOCK) ON RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey    
                  WHERE RECEIPTDETAIL.ReceiptKey = @c_ReceiptKeyUpdate    
                  AND RECEIPTDETAIL.ReceiptLineNumber = @c_ReceiptLineUpdate    
                  AND (RECEIPTDETAIL.UserDefine10 = '' OR RECEIPTDETAIL.UserDefine10 IS NULL)    
                   
                  IF @@ERROR <> 0     
                  BEGIN     
                     SET @n_Continue = 3    
                     SET @n_Err = 63080    
                     SET @c_ErrMsg = CONVERT(CHAR(5), @n_Err) + ': Error Update RECEIPTDETAIL Fail.'    
                                   + '. (ispBatPA04)'     
                     GOTO QUIT_SP     
                  END      
               END    
            END --@n_PAInsertQty > 0    
              
            NEXT_LINE:    
            SET @c_PrevReceiptkey = @c_CurrReceiptkey    
            SET @c_PrevReceiptLineNumber = @c_ReceiptLineNumber     
         END--@n_PAToLocQty > 0             
           
         NEXT_LOC:  
      END--@nSkuQtyRemaining > 0    
          
      WHILE @@TRANCOUNT > 0 AND @c_CommitPerSku = 'Y'    
      BEGIN     
         COMMIT TRAN    
      END    
    
      NEXT_SKU:         
    
      FETCH NEXT FROM @CUR_RDSKU INTO @c_Storerkey    
                                    , @c_Sku    
                                    , @c_ItemClass     
                                    , @c_SkuGroup  --JS  
                                    , @n_SkuQtyReceived      
                                    , @c_PrePackIndicator    
                                    , @n_PackQtyIndicator     
                                    , @n_CaseCnt    
                                    --, @c_RDLottable02                                       
   END    
   CLOSE @CUR_RDSKU    
   DEALLOCATE @CUR_RDSKU     
       
QUIT_SP:    
  
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
          
      IF @c_CommitPerSku = 'Y'    
      BEGIN    
         --IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt      
         IF @@TRANCOUNT > 0 --@n_StartTCnt    
         BEGIN    
            ROLLBACK TRAN    
         END    
         --ELSE    
         --BEGIN    
         --   WHILE @@TRANCOUNT > @n_StartTCnt    
         --   BEGIN    
         --      COMMIT TRAN    
         --   END    
         --END        
      END    
      ELSE    
      BEGIN    
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
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR      
      END    
          
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispBatPA04'    
   END    
   ELSE    
   BEGIN    
      SET @b_Success = 1    
      IF @c_CommitPerSku = 'Y'    
         WHILE @@TRANCOUNT > 0 -- @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END    
      ELSE    
         WHILE @@TRANCOUNT > @n_StartTCnt    
         BEGIN    
            COMMIT TRAN    
         END             
   END    
    
   IF OBJECT_ID('tempdb..#TMP_PALOC','u') IS NOT NULL    
   DROP TABLE #TMP_PALOC;    
  
   IF OBJECT_ID('tempdb..#TMP_UCC','u') IS NOT NULL    
   DROP TABLE #TMP_UCC;    
  
   IF OBJECT_ID('tempdb..#TMP_SKUQTYSUMM','u') IS NOT NULL    
   DROP TABLE #TMP_SKUQTYSUMM;    
    
   WHILE @@TRANCOUNT < @n_StartTCnt AND @c_CommitPerSku = 'Y'    
   BEGIN    
      BEGIN TRAN    
   END    
END -- procedure  

GO