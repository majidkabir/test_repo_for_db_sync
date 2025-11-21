SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_ReplenishmentRpt_BatchRefill_15                */  
/* Creation Date: 28-AUG-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: CNA China Replenishment Report                              */  
/*          SOS#287818: CNA Replenish & Swap Lot                        */  
/*                                                                      */  
/* Called By: r_replenishment_report15                                  */  
/*                                                                      */  
/* PVCS Version: 1.8                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver.  Purposes                                  */  
/* 27-Mar-2014  YTWan   1.1   SOS#305100 - CR for RCM Report            */  
/*                            r_replenishment_report15 (Wan01)          */  
/* 10-Jun-2014  Audrey  1.2   SOS313330 - Logic fixed            (ang01)*/  
/* 15-OCT-2015  YTwan   1.3   SOS#342676 - CR for replenishment report  */  
/*                            (WAN02)                                   */  
/* 29-Mar-2016  NJOW01  1.4   367157-Replenishment filter lottable by   */
/*                            codelkup setting                          */
/* 04-JAN-2017  Wan03   1.5   WMS-858 - CN CNA Replenishment report CR  */    
/* 17-JAN-2017  Wan03   1.5   Fixed QtyAvailable issue                  */  
/* 14-Sep-2017  TLTING  1.6   Missing NOLOCK                            */  
/* 14-Sep-2017  TLTING  1.6   Dynamic SQL avoid recompile               */  
/* 05-MAR-2018  Wan04    1.7   WM - Add Functype                        */
/* 05-OCT-2018  CZTENG01 1.8   WM - Add ReplGrp                         */ 
/************************************************************************/  
CREATE PROC  [dbo].[isp_ReplenishmentRpt_BatchRefill_15]  
               @c_Zone01      NVARCHAR(10)  -- Facility  
,              @c_Zone02      NVARCHAR(10)  -- All PutawayZone  
,              @c_Zone03      NVARCHAR(10)  
,              @c_Zone04      NVARCHAR(10)  
,              @c_Zone05      NVARCHAR(10)  
,              @c_Zone06      NVARCHAR(10)  
,              @c_Zone07      NVARCHAR(10)  
,              @c_Zone08      NVARCHAR(10)  
,              @c_Zone09      NVARCHAR(10)  
,              @c_Zone10      NVARCHAR(10)  
,              @c_Zone11      NVARCHAR(10)  
,              @c_Zone12      NVARCHAR(10)  
,              @c_storerkey   NVARCHAR(15) 
,              @c_ReplGrp     NVARCHAR(30) = 'ALL' --(CZTENG01)
,              @c_Functype    NCHAR(1)     = ''    --(Wan04)   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue           INT          /* continuation flag  
                                                1=Continue  
                                                2=failed but continue processsing  
                                                3=failed do not continue processing  
                                                4=successful but skip furthur processing */  
         , @n_StartTCnt          INT  
         , @b_debug              INT  
         , @b_success            INT  
         , @n_err                INT  
         , @c_errmsg             NVARCHAR(255)  
  
         , @c_SQLStatement       NVARCHAR(MAX)  
         , @c_SQLConditions      NVARCHAR(MAX)  
  
   DECLARE @n_RowRef             INT  
         , @n_Row                INT  
         , @n_ReplenishmentKey   INT  
         , @c_ReplenishmentKey   NVARCHAR(10)  
         , @c_ReplenishmentGrp   NVARCHAR(10)  
  
   DECLARE @c_CurrentStorer      NVARCHAR(15)  
         , @c_CurrentSku         NVARCHAR(20)  
         , @c_CurrentLOC         NVARCHAR(10)  
         , @c_CurrentPriority    NVARCHAR(5)  
         , @c_FromLoc            NVARCHAR(10)  
         , @c_FromLot            NVARCHAR(10)  
         , @c_FromID             NVARCHAR(18)  
         , @c_Packkey            NVARCHAR(10)  
         , @c_UOM                NVARCHAR(10)  
         , @c_LocationType       NVARCHAR(10)  
  
  
         , @n_QtyOverAlloc       INT  
         , @n_OnHandQty          INT  
         , @n_FromQty            INT  
         , @n_Qty                INT  
         , @n_QtyAllocated       INT  
         , @n_QtyPicked          INT  
         , @n_QtyExpected        INT  
         , @n_QtyExpNeeded       INT  
  
         , @n_QtyAvailable       INT  
         , @n_QtyToReplen        INT  
         , @n_LeftToReplen       INT  
         , @n_QtyLocationMinimum INT  
         , @n_QtyLocationLimit   INT  
         , @n_QtyInLoc           INT  
         , @n_LotSKUQTY          INT  
         , @n_Casecnt            FLOAT  
         , @n_Pallet             INT  
         , @n_FullPackQty        INT  
  
         , @n_GroupType          INT  
         , @n_GroupTypePrev      INT  
         , @c_SortColumn         NVARCHAR(20)  
         , @n_RowNo              INT  
   
   --NJOW01      
   DECLARE @c_Lottable01         NVARCHAR(18)
          ,@c_Lottable02         NVARCHAR(18)
          ,@c_Lottable03         NVARCHAR(18)
          ,@dt_Lottable04        DATETIME
          ,@dt_Lottable05        DATETIME
          ,@c_Lottable06         NVARCHAR(30)
          ,@c_Lottable07         NVARCHAR(30)
          ,@c_Lottable08         NVARCHAR(30)
          ,@c_Lottable09         NVARCHAR(30)
          ,@c_Lottable10         NVARCHAR(30)
          ,@c_Lottable11         NVARCHAR(30)
          ,@c_Lottable12         NVARCHAR(30)
          ,@dt_Lottable13        DATETIME
          ,@dt_Lottable14        DATETIME
          ,@dt_Lottable15        DATETIME
          ,@cSQLParm             NVARCHAR(1000) = '' -- tlting
 
   SET @n_Continue         = 1  
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_debug            = 0  
   SET @b_success          = 1  
   SET @n_err              = 0  
   SET @c_errmsg           = ''  
  
   SET @c_SQLStatement     = ''  
   SET @c_SQLConditions    = ''  
  
   SET @n_RowRef           = 0  
   SET @n_Row              = 0  
   SET @n_ReplenishmentKey = 0  
   SET @c_ReplenishmentKey = ''  
   SET @c_ReplenishmentGrp = 'ALL'  
  
   SET @c_CurrentStorer    = ''  
   SET @c_CurrentSku       = ''  
   SET @c_CurrentLOC       = ''  
   SET @c_CurrentPriority  = ''  
   SET @c_FromLoc          = ''  
   SET @c_FromID           = ''  
   SET @c_Packkey          = ''  
   SET @c_UOM              = ''  
  
   SET @n_QtyOverAlloc     = 0  
   SET @n_OnHandQty        = 0  
  
   SET @n_FromQty          = 0  
   SET @n_Qty              = 0  
   SET @n_QtyAllocated     = 0  
   SET @n_QtyPicked        = 0  
   SET @n_QtyExpected      = 0  
   SET @n_QtyExpNeeded     = 0  
  
   SET @n_QtyAvailable     = 0  
   SET @n_QtyToReplen      = 0  
   SET @n_QtyLocationMinimum= 0  
   SET @n_QtyLocationLimit = 0  
   SET @n_QtyInLoc         = 0  
  
   SET @n_LotSKUQTY        = 0  
   SET @n_Casecnt          = 0  
   SET @n_Pallet           = 0  
   SET @n_FullPackQty      = 0  
  
   SET @c_SortColumn       = ''  
   SET @n_GroupTypePrev    = 0  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   --(Wan04) - START
   IF ISNULL(@c_ReplGrp,'') = ''
   BEGIN
      SET @c_ReplGrp = 'ALL'
   END
   --(Wan04) - END     
     
   IF @c_FuncType = 'P'                                         --(Wan04)
   BEGIN                                                        --(Wan04) 
      GOTO QUIT
   END

   CREATE TABLE #REPLENISHMENT  
      (  
         RowRef            INT IDENTITY(1,1) NOT NULL PRIMARY KEY  
      ,  ReplenishmentGrp  NVARCHAR(10)   NOT NULL    DEFAULT ''  
      ,  StorerKey         NVARCHAR(20)   NOT NULL  
      ,  SKU               NVARCHAR(20)   NOT NULL  
      ,  FromLoc           NVARCHAR(10)   NOT NULL  
      ,  ToLoc             NVARCHAR(10)   NOT NULL  
      ,  LOT               NVARCHAR(10)   NOT NULL  
      ,  ID                NVARCHAR(18)   NOT NULL  
      ,  QTY               INT            NOT NULL  
      ,  QtyMoved          INT            NOT NULL  
      ,  QtyInPickLOC      INT            NOT NULL  
      ,  Priority          NVARCHAR(5)  
      ,  UOM               NVARCHAR(10)   NOT NULL  
      ,  Packkey           NVARCHAR(10)   NOT NULL  
         )  
  
   CREATE TABLE #LOT_SORT  
   (  
      Lot               NVARCHAR(10)  
   ,  GroupType         INT                -- 1) OverAllocate 2) Normal  
   ,  QtyToReplen       INT  
   ,  SortColumn        NVARCHAR(50)  
  
   )  
  
   IF @c_Storerkey <> 'ALL'  
   BEGIN  
      SET @c_SQLConditions = ' AND SKUxLOC.Storerkey = RTRIM(@c_Storerkey) '   -- tlting
   END  
  
   IF (@c_Zone02 <> 'ALL')  
   BEGIN  
      SET @c_SQLConditions = @c_SQLConditions  
                           + ' AND LOC.PutawayZone IN ( RTRIM(@c_Zone02) '   -- tlting
                           +                          ', RTRIM(@c_Zone03) '  
                           +                          ', RTRIM(@c_Zone04) '  
                           +                          ', RTRIM(@c_Zone05) '  
                           +                          ', RTRIM(@c_Zone06) '  
                           +                          ', RTRIM(@c_Zone07) '  
                           +                          ', RTRIM(@c_Zone08) '  
                           +                          ', RTRIM(@c_Zone09) '  
                           +                          ', RTRIM(@c_Zone10) '  
                           +                          ', RTRIM(@c_Zone11) '  
                           +                          ', RTRIM(@c_Zone12) )'  
  
   END  
  
   SET @c_SQLStatement     = N'DECLARE CUR_SKUxLOC CURSOR FAST_FORWARD READ_ONLY FOR'  
                           + ' SELECT ReplenishmentPriority = ISNULL(RTRIM(SKUxLOC.ReplenishmentPriority),'''')'  
                           + ',StorerKey = ISNULL(RTRIM(SKUxLOC.StorerKey),'''')'  
                           + ',Sku = ISNULL(RTRIM(SKUxLOC.SKU),'''')'  
                           + ',Loc = ISNULL(RTRIM(SKUxLOC.LOC),'''')'  
                           --+ ',QtyExpected = SUM(ISNULL(CEILING(LOTxLOCxID.QtyExpected /(ISNULL(PACK.CaseCnt,0.00)*1.00)) * ISNULL(PACK.CaseCnt,0.00),0))'  
                           + ',QtyExpected = ISNULL(SUM(LOTxLOCxID.QtyExpected),0)'  
                           + ',Qty = ISNULL(SKUxLOC.Qty,0)'  
                           + ',QtyPicked = ISNULL(SKUxLOC.QtyPicked,0)'  
                           + ',QtyAllocated = ISNULL(SKUxLOC.QtyAllocated,0)'  
                           + ',QtyLocationLimit = ISNULL(SKUxLOC.QtyLocationLimit,0)'  
                           + ',QtyLocationMinimum = ISNULL(SKUxLOC.QtyLocationMinimum,0)'  
                           + ',CaseCnt = ISNULL(PACK.CaseCnt,0.00)'  
                           + ',Pallet = ISNULL(PACK.Pallet,0.00)'  
                           + ',LocationType = ISNULL(RTRIM(SKUxLOC.LocationType),'''')'  
                           + ' FROM    SKUxLOC WITH (NOLOCK)'  
                           + ' JOIN    LOTxLOCxID WITH (NOLOCK) ON (SKUxLOC.Storerkey = LOTxLOCxID.Storerkey)'  
                           +                                  ' AND(SKUxLOC.Sku = LOTxLOCxID.Sku)'  
                           +                                  ' AND(SKUxLOC.Loc = LOTxLOCxID.Loc)'  
                           + ' JOIN    LOC WITH  (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)'  
                           + ' JOIN    SKU WITH  (NOLOCK) ON (SKU.StorerKey = SKUxLOC.StorerKey)'  
                           +                            ' AND(SKU.SKU = SKUxLOC.SKU)'  
                           + ' JOIN    PACK WITH (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)'  
                           + ' WHERE   LOC.Facility = ISNULL(RTRIM(@c_Zone01),'''') '   -- tlting
                           + ' AND SKUxLOC.LocationType IN ( ''PICK'', ''CASE'' )'  
                           + ' AND LOC.LocationFlag NOT IN ( ''DAMAGE'', ''HOLD'' )'  
                           + RTRIM(ISNULL(@c_SQLConditions,''))  
                           + ' GROUP BY '  
                           + ' ISNULL(RTRIM(SKUxLOC.ReplenishmentPriority),'''')'  
                           + ',ISNULL(RTRIM(SKUxLOC.StorerKey),'''')'  
                           + ',ISNULL(RTRIM(SKUxLOC.SKU),'''')'  
                           + ',ISNULL(RTRIM(SKUxLOC.LOC),'''')'  
                           + ',ISNULL(SKUxLOC.Qty,0)'  
                           + ',ISNULL(SKUxLOC.QtyPicked,0)'  
                           + ',ISNULL(SKUxLOC.QtyAllocated,0)'  
                           + ',ISNULL(SKUxLOC.QtyLocationLimit,0)'  
                           + ',ISNULL(SKUxLOC.QtyLocationMinimum,0)'  
                           + ',ISNULL(PACK.CaseCnt,0.00)'  
                           + ',ISNULL(PACK.Pallet,0.00)'  
                           + ',ISNULL(RTRIM(SKUxLOC.LocationType),'''')'  
                           + ' HAVING SUM(LOTxLOCxID.QtyExpected) > 0 OR ISNULL(SKUxLOC.QtyLocationMinimum,0) > (ISNULL(SKUxLOC.Qty,0) - (ISNULL(SKUxLOC.QtyPicked,0) + ISNULL(SKUxLOC.QtyAllocated,0)))'  
                           + ' ORDER BY ISNULL(RTRIM(SKUxLOC.ReplenishmentPriority),''''), ISNULL(RTRIM(SKUxLOC.LOC),'''')'  

   -- tlting
   SET @cSQLParm = N'@c_Storerkey NVARCHAR(15), '
                   +'@c_Zone01    NVARCHAR(10), ' 
                   +'@c_Zone02    NVARCHAR(10), '  
                   +'@c_Zone03    NVARCHAR(10), '  
                   +'@c_Zone04    NVARCHAR(10), '  
                   +'@c_Zone05    NVARCHAR(10), '  
                   +'@c_Zone06    NVARCHAR(10), '  
                   +'@c_Zone07    NVARCHAR(10), '  
                   +'@c_Zone08    NVARCHAR(10), '  
                   +'@c_Zone09    NVARCHAR(10), '  
                   +'@c_Zone10    NVARCHAR(10), '  
                   +'@c_Zone11    NVARCHAR(10), '  
                   +'@c_Zone12    NVARCHAR(10) ' 

   EXEC sp_executesql @c_SQLStatement, @cSQLParm, @c_Storerkey, @c_Zone01, @c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, 
                     @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09, @c_Zone10, @c_Zone11, @c_Zone12
  
   OPEN CUR_SKUxLOC  
  
   FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentPriority  
                                 ,  @c_CurrentStorer  
                                 ,  @c_CurrentSku  
                                 ,  @c_CurrentLoc  
                                 ,  @n_QtyExpected  
                                 ,  @n_Qty  
                                 ,  @n_QtyPicked  
                                 ,  @n_QtyAllocated  
                                 ,  @n_QtyLocationLimit  
                                 ,  @n_QtyLocationMinimum  
                                 ,  @n_CaseCnt  
                                 ,  @n_Pallet  
                                 ,  @c_LocationType  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
--      IF NOT EXISTS( SELECT 1  
--                     FROM LOTxLOCxID   LLI WITH (NOLOCK)  
--                     JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot)  
--                     JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'REPLSWAP')  
--                                                         AND(LLI.Storerkey = CL.Storerkey)  
--                                                         AND(LA.Lottable02 = CL.Short)  
--                                                         AND(CL.UDF01 = '0')  
--                     WHERE LLI.Loc       = @c_CurrentLoc  
--                     AND   LLI.Storerkey = @c_CurrentStorer  
--                     AND   LLI.Sku       = @c_CurrentSku )  
--      BEGIN  
--         GOTO NEXT_SKUxLOC  
--      END  
  
      IF EXISTS(SELECT 1 FROM REPLENISHMENT R WITH (NOLOCK)  
                WHERE R.Storerkey = @c_CurrentStorer  
                AND  R.Sku = @c_CurrentSku  
                AND  R.ToLoc = @c_CurrentLoc  
                AND  R.Confirmed = 'N')  
      BEGIN  
         IF @b_debug = 1  
         BEGIN  
            PRINT 'Deleting Previous Replenishment Record'  
            PRINT '  SKU: ' + @c_CurrentSKU  
            PRINT '  LOC: ' + @c_CurrentLOC  
         END  
  
         DELETE REPLENISHMENT  
         FROM REPLENISHMENT R  
         JOIN SKUxLOC SL WITH (NOLOCK) ON (SL.StorerKey = R.Storerkey)  
                                       AND(SL.Sku = R.Sku)  
                                       AND(SL.Loc = R.ToLoc)  
         WHERE R.Storerkey = @c_CurrentStorer  
         AND   R.Sku = @c_CurrentSKU  
         AND   R.ToLoc = @c_CurrentLOC  
         AND   R.Confirmed = 'N'  
         AND   SL.LocationType = @c_LocationType  
         AND  (R.ReplenishmentGroup NOT IN('DYNAMIC')  
         AND  (R.ReplenishmentGroup = 'IDS'))  
  
      END  
  
      IF @n_CaseCnt = 0 SET @n_CaseCnt = 1  
  
      SET @n_QtyInLoc = @n_Qty - @n_QtyAllocated - @n_QtyPicked --+ @n_QtyExpected  
      --SET @n_LeftToReplen = @n_QtyLocationLimit - (@n_Qty - (@n_QtyAllocated + @n_QtyPicked)) - @n_QtyExpected  
  
  
      --IF @n_LeftToReplen < 0  
      --BEGIN  
      --   SET @n_LeftToReplen = CASE WHEN @c_LocationType = 'PICK' THEN @n_QtyLocationLimit  
      --                              WHEN @c_LocationType = 'CASE' THEN @n_Pallet  
      --                              END  
      --END  
  
  
      DELETE #LOT_SORT  
  
      IF @n_QtyExpected > 0  
      BEGIN  
  
         INSERT INTO #LOT_SORT  
            (  
               LOT  
            ,  GroupType  
            ,  QtyToReplen  
            ,  SortColumn  
            )  
  
         SELECT DISTINCT  
                LLI.LOT  
              , GroupType  = 1  
              , CEILING(((LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty)/@n_CaseCnt) * @n_CaseCnt  
              , SortColumn = ' '  
                           + CONVERT(CHAR(8), ISNULL(LA.Lottable05, '1900-01-01') ,112)  
                           + LEFT(ISNULL(RTRIM(LA.Lottable02),'') + REPLICATE(' ',18),18)  
                           + LLI.Lot  
         FROM LOTxLOCxID   LLI WITH (NOLOCK)  
         JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot)  
         JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'REPLSWAP')  
                                             AND(LLI.Storerkey = CL.Storerkey)  
                                             AND(LA.Lottable02 = CL.Short)  
                                             AND(CL.UDF01 = '0')  
         WHERE LLI.Loc       = @c_CurrentLoc  
         AND   LLI.Storerkey = @c_CurrentStorer  
         AND   LLI.Sku       = @c_CurrentSku  
         AND  (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty > 0  
         AND   EXISTS ( SELECT 1  
                        FROM LOTxLOCxID   WITH (NOLOCK)  
                        JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)  
                        WHERE LOTxLOCxID.Loc       = LLI.Loc  
                        AND   LOTxLOCxID.Storerkey = LLI.Storerkey  
                        AND   LOTxLOCxID.Sku       = LLI.Sku  
                        AND   LOTATTRIBUTE.Lottable02 = LA.Lottable02  
                        GROUP BY  LOTATTRIBUTE.Lottable02  
                        HAVING SUM((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty) > 0)  
  
         ORDER BY SortColumn  
      END  
  
      --NJOW01
      SELECT @c_Lottable01 = '', @c_Lottable02 = '', @c_Lottable03 = '', @dt_Lottable04 = null, @dt_Lottable05 = null, @c_Lottable06 = '',
             @c_Lottable07 = '', @c_Lottable08 = '', @c_Lottable09 = '', @c_Lottable10 = '', @c_Lottable11 = '', @c_Lottable12 = '', 
             @dt_Lottable13 = null, @dt_Lottable14 = null, @dt_Lottable15 = null
             
      SELECT TOP 1 @c_Lottable01 = LA.Lottable01, @c_Lottable02 = LA.Lottable02, @c_Lottable03 = LA.Lottable03,
                   @dt_Lottable04 = LA.Lottable04, @dt_Lottable05 = LA.Lottable05, @c_Lottable06 = LA.Lottable06,
                   @c_Lottable07 = LA.Lottable07, @c_Lottable08 = LA.Lottable08, @c_Lottable09 = LA.Lottable09,      
                   @c_Lottable10 = LA.Lottable10, @c_Lottable11 = LA.Lottable11, @c_Lottable12 = LA.Lottable12,      
                   @dt_Lottable13 = LA.Lottable13, @dt_Lottable14 = LA.Lottable14, @dt_Lottable15 = LA.Lottable15
      FROM LOTxLOCxID   LLI WITH (NOLOCK)  
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.Lot = LA.Lot)  
      JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'REPLSWAP')  
                                          AND(LLI.Storerkey = CL.Storerkey)  
                                          AND(LA.Lottable02 = CL.Short)  
                                          AND(CL.UDF01 = '1')  
      WHERE LLI.Loc       = @c_CurrentLoc  
      AND   LLI.Storerkey = @c_CurrentStorer  
      AND   LLI.Sku       = @c_CurrentSku  
      AND  (LLI.QtyAllocated + LLI.QtyPicked) - LLI.Qty > 0  
      AND   EXISTS ( SELECT 1  
                     FROM LOTxLOCxID   WITH (NOLOCK)  
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)  
                     WHERE LOTxLOCxID.Loc       = LLI.Loc  
                     AND   LOTxLOCxID.Storerkey = LLI.Storerkey  
                     AND   LOTxLOCxID.Sku       = LLI.Sku  
                     AND   LOTATTRIBUTE.Lottable02 = LA.Lottable02  
                     GROUP BY  LOTATTRIBUTE.Lottable02  
                     HAVING SUM((LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty) > 0)                                
  
      INSERT INTO #LOT_SORT  
         (  LOT  
         ,  GroupType  
         ,  QtyToReplen  
         ,  SortColumn  
         )  
      SELECT DISTINCT  
             LLI.LOT  
           , GroupType  = 2  
           , 0  
           , SortColumn = ISNULL(RTRIM(CL.Long),'9')  
                        + CONVERT(CHAR(8), ISNULL(LA.Lottable05, '1900-01-01') ,112)  
                        + LEFT(ISNULL(RTRIM(LA.Lottable02),'') + REPLICATE(' ',18),18)  
                        + LLI.Lot  
      FROM LOTxLOCxID   LLI WITH (NOLOCK)  
      JOIN LOC          LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)  
      JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LLI.LOT = LA.LOT)  
      JOIN LOT          LOT WITH (NOLOCK) ON (LLI.LOT = LOT.LOT)  
      JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID = ID.ID)  
      JOIN SKUxLOC      SL  WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey)  
                                          AND(LLI.SKU = SL.SKU)  
                                          AND(LLI.LOC = SL.LOC)  
      JOIN CODELKUP     CL  WITH (NOLOCK) ON (CL.ListName = 'REPLSWAP')  
                                          AND(LLI.Storerkey = CL.Storerkey)  
                                          AND(LA.Lottable02 = CL.Short)  
                                          --AND(CL.UDF01 = '0') ang01  
      WHERE SL.StorerKey = @c_CurrentStorer  
      AND  SL.SKU = @c_CurrentSku  
      AND  SL.LOC <> @c_CurrentLOC  
      AND  SL.LocationType  NOT IN ('CASE','PICK')  
      AND  LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
      AND  LOC.Facility = @c_Zone01  
      AND  LOC.Status = 'OK'  
      AND  LOT.Status = 'OK'  
      AND  ID.Status  = 'OK'  
      AND (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  
      --AND  NOT EXISTS(SELECT 1 FROM #LOT_SORT L WHERE L.LOT = LLI.LOT)  
      AND LA.Lottable01 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE01', CL.Notes) > 0 THEN ISNULL(@c_Lottable01,'') ELSE LA.Lottable01 END  --NJOW01
      AND LA.Lottable02 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE02', CL.Notes) > 0 THEN ISNULL(@c_Lottable02,'') ELSE LA.Lottable02 END
      AND LA.Lottable03 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE03', CL.Notes) > 0 THEN ISNULL(@c_Lottable03,'') ELSE LA.Lottable03 END
      AND ISNULL(LA.Lottable04,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE04', CL.Notes) > 0 THEN ISNULL(@dt_Lottable04,'') ELSE ISNULL(LA.Lottable04,'') END
      AND ISNULL(LA.Lottable05,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE05', CL.Notes) > 0 THEN ISNULL(@dt_Lottable05,'') ELSE ISNULL(LA.Lottable05,'') END
      AND LA.Lottable06 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE06', CL.Notes) > 0 THEN ISNULL(@c_Lottable06,'') ELSE LA.Lottable06 END
      AND LA.Lottable07 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE07', CL.Notes) > 0 THEN ISNULL(@c_Lottable07,'') ELSE LA.Lottable07 END
      AND LA.Lottable08 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE08', CL.Notes) > 0 THEN ISNULL(@c_Lottable08,'') ELSE LA.Lottable08 END
      AND LA.Lottable09 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE09', CL.Notes) > 0 THEN ISNULL(@c_Lottable09,'') ELSE LA.Lottable09 END
      AND LA.Lottable10 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE10', CL.Notes) > 0 THEN ISNULL(@c_Lottable10,'') ELSE LA.Lottable10 END
      AND LA.Lottable11 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE11', CL.Notes) > 0 THEN ISNULL(@c_Lottable11,'') ELSE LA.Lottable11 END
      AND LA.Lottable12 = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE12', CL.Notes) > 0 THEN ISNULL(@c_Lottable12,'') ELSE LA.Lottable12 END
      AND ISNULL(LA.Lottable13,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE13', CL.Notes) > 0 THEN ISNULL(@dt_Lottable13,'') ELSE ISNULL(LA.Lottable13,'') END
      AND ISNULL(LA.Lottable14,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE14', CL.Notes) > 0 THEN ISNULL(@dt_Lottable14,'') ELSE ISNULL(LA.Lottable14,'') END
      AND ISNULL(LA.Lottable15,'') = CASE WHEN CL.Notes2 = '1' AND CHARINDEX('LOTTABLE15', CL.Notes) > 0 THEN ISNULL(@dt_Lottable15,'') ELSE ISNULL(LA.Lottable15,'') END
      ORDER BY SortColumn  
  
      IF NOT EXISTS ( SELECT 1 FROM #LOT_SORT )  
      BEGIN  
         GOTO NEXT_SKUxLOC  
      END  
  
      IF @b_debug = 1  
      BEGIN  
         Print 'Working on @c_CurrentPriority: ' +  RTRIM(@c_CurrentPriority) +  
               ', @c_CurrentStorer:' + RTRIM(@c_CurrentStorer) +  
               ', @c_CurrentSku:' + RTRIM(@c_CurrentSku) +  
               ', @c_CurrentLOC:' + RTRIM(@c_CurrentLOC) +  
               ', @n_Qty:' + Convert(VARCHAR(10),@n_Qty) +  
               ', @n_QtyPicked:' + Convert(VARCHAR(10),@n_QtyPicked) +  
               ', @n_QtyAllocated:' + Convert(VARCHAR(10),@n_QtyAllocated) +  
               ', @n_QtyLocationLimit:' + Convert(VARCHAR(10),@n_QtyLocationLimit) +  
               ', @n_QtyLocationMinimum:' + Convert(VARCHAR(10),@n_QtyLocationMinimum) +  
               ', @n_CaseCnt:' + Convert(VARCHAR(10),@n_CaseCnt) +  
               ', @n_Pallet:' + Convert(VARCHAR(10),@n_Pallet) +  
               ', @c_LocationType:' + RTRIM(@c_LocationType) +  
               ', @n_QtyToReplen: ' + Convert(VARCHAR(10),@n_QtyToReplen)  
      END  
  
      DECLARE CUR_LOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT  
            Lot  
           ,GroupType  
           ,QtyToReplen  
           ,SortColumn  
      FROM #LOT_SORT  
      ORDER BY GroupType  
            ,  SortColumn  
  
      OPEN CUR_LOT  
  
      FETCH NEXT FROM CUR_LOT INTO @c_FromLot  
                                 , @n_GroupType  
                                 , @n_QtyToReplen  
                                 , @c_SortColumn  
  
  
      WHILE @@FETCH_STATUS <> -1 --AND @n_LeftToReplen > 0  
      BEGIN    
         IF @n_GroupType = 2  
         BEGIN  
            --IF @n_GroupTypePrev <> @n_GroupType AND @n_QtyInLoc >= @n_QtyLocationMinimum  --Add =  
            --IF @n_QtyInLoc >= @n_QtyLocationMinimum  
            --IF @n_GroupTypePrev <> @n_GroupType (ang01)  
            --BEGIN  
               IF @n_QtyInLoc >= @n_QtyLocationMinimum  
               BEGIN  
                  GOTO NEXT_SKUxLOC  
               END  
  
               SET @n_LeftToReplen= @n_QtyLocationLimit - @n_QtyInLoc --( CASE WHEN  @n_QtyInLoc > 0 THEN @n_QtyInLoc ELSE @n_QtyInLoc * -1 END )  
  
               SET @n_QtyToReplen = FLOOR(@n_LeftToReplen/(@n_CaseCnt * 1.00)) * @n_CaseCnt  --@n_LeftToReplen  
            --END  
  
            --SET @n_LeftToReplen= @n_QtyLocationLimit - @n_QtyInLoc --( CASE WHEN  @n_QtyInLoc > 0 THEN @n_QtyInLoc ELSE @n_QtyInLoc * -1 END )  
  
            --SET @n_QtyToReplen = FLOOR(@n_LeftToReplen/(@n_CaseCnt * 1.00)) * @n_CaseCnt  --@n_LeftToReplen  
  
            IF @n_QtyToReplen <= 0  
            BEGIN  
               GOTO NEXT_SKUxLOC  
            END  
         END  
  
         IF @b_debug = 1  
         BEGIN  
            Print 'Working on @c_FromLot: ' +  RTRIM(@c_FromLot) +  
                  ', @n_GroupType:' + RTRIM(@n_GroupType) +  
                  ', @n_QtyToReplen:' + Convert(VARCHAR(10),@n_QtyToReplen) +  
                  ', @c_SortColumn:' + RTRIM(@c_SortColumn) 
         END  

         DECLARE CUR_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LLI.LOC  
               ,LLI.ID  
               ,OnHandQty = (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)  
         FROM LOTxLOCxID LLI WITH (NOLOCK)  
         JOIN LOT LOT        WITH (NOLOCK) ON (LLI.Lot = LOT.Lot)  
         JOIN LOC LOC        WITH (NOLOCK) ON (LLI.LOC = LOC.Loc)  
         JOIN ID  ID         WITH (NOLOCK) ON (LLI.ID = ID.Id)  
         JOIN SKUxLOC SL     WITH (NOLOCK) ON (LLI.StorerKey = SL.StorerKey)  
                                           AND(LLI.SKU = SL.SKU)  
                                           AND(LLI.LOC = SL.LOC)  
         WHERE LLI.LOT = @c_FromLot  
         AND   LOC.LocationFlag NOT IN ('DAMAGE', 'HOLD')  
         AND   LOC.Facility = @c_Zone01  
         AND   LOT.Status = 'OK'  
         AND   LOC.Status = 'OK'  
         AND   ID.Status  = 'OK'  
         AND   SL.Locationtype NOT IN ('CASE','PICK')  
         AND  (LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated) > 0  
         ORDER BY CASE WHEN @n_GroupType = 1 AND LLI.Qty % CONVERT(INT,@n_CaseCnt) = 0 THEN 0  
                       WHEN @n_GroupType = 1 AND LLI.Qty % CONVERT(INT,@n_CaseCnt) > 0 THEN 1  
                       WHEN @n_GroupType = 2 AND LLI.Qty % CONVERT(INT,@n_CaseCnt) = 0 THEN 0  
                       ELSE 1 END  
               ,  OnHandQty  
               ,  LOC.LogicalLocation  
  
         OPEN CUR_REPLEN  
  
         FETCH NEXT FROM CUR_REPLEN INTO @c_FromLoc  
                                       , @c_FromID  
                                       , @n_OnHandQty  
         WHILE @@FETCH_STATUS <> -1 AND @n_QtyToReplen > 0  
         BEGIN  
  
            IF @b_debug = 1  
            BEGIN  
              Print 'Working on @c_FromLoc: ' +  RTRIM(@c_FromLoc) +  
                    ', @c_FromID:' + RTRIM(@c_FromID) +  
                    ', @n_OnHandQty:' + Convert(VARCHAR(10),@n_OnHandQty) 
            END  

            SET @n_LotSKUQTY = 0  
  
            SELECT @n_LotSKUQTY =ISNULL(SUM(QTY) ,0)  
            From #Replenishment (NOLOCK)  
            Where Lot = @c_FromLot  
            AND FromLOC = @c_FromLoc  
            AND ID = @c_FromId  
  
            If @b_debug = 1  
            BEGIN  
              PRINT '*****'  
              SELECT 'Original Lot QTY: ' , @n_OnHandQty, 'Located Replen QTY: ' , @n_LotSKUQTY  
              SELECT '@c_fromLot: ' , @c_FromLot  
            END  
  
            SET @n_OnHandQty = @n_OnHandQty - ISNULL(@n_LotSKUQTY,0)  
  
            IF @n_OnHandQTy <= 0  
            BEGIN  
               GOTO NEXT_CANDIDATE  
            END  
  
  
            IF @b_debug = 1  
            BEGIN  
               PRINT '>>>  On Hand Qty: ' + CONVERT(NVARCHAR(10), @n_OnHandQty)  
               PRINT '     Case Cnt:' + CONVERT(NVARCHAR(10), @n_CaseCnt)  
               PRINT '>>>  Qty In Loc: ' + CONVERT(NVARCHAR(10), @n_QtyInLoc)  
               PRINT '     Qty To Replen: ' + CONVERT(NVARCHAR(10), @n_QtyToReplen)  
            END  
  
            SET @n_FromQty = @n_OnHandQty  
  
            ----------------------------------------------------------------------------------------------------  
--            IF @n_FromQty > @n_CaseCnt  
--            BEGIN  
--               IF @n_FromQty > @n_QtyToReplen  
--               BEGIN  
--                  IF (CEILING(@n_QtyToReplen / (@n_CaseCnt * 1.00)) * @n_CaseCnt) < @n_FromQty  
--                  BEGIN  
--                      SET @n_FromQty = CEILING(@n_QtyToReplen / (@n_CaseCnt * 1.00)) * @n_CaseCnt  
--                  END  
--                  ELSE  
--                  BEGIN  
--                      SET @n_FromQty = FLOOR(@n_FromQty/(@n_CaseCnt * 1.00)) * @n_CaseCnt  
--                  END  
--               END  
--            END  
  
  
--            BEGIN  
               IF @n_FromQty > @n_QtyToReplen  
               BEGIN  
                  SET @n_FromQty = @n_QtyToReplen  
               END  
--            END  
  
  
            SET @n_QtyInLoc = @n_QtyInLoc + @n_FromQty  
            SET @n_QtyToReplen = @n_QtyToReplen - @n_FromQty  
  
            --SET @n_LeftToReplen = @n_LeftToReplen - @n_FromQty  
  
            ----------------------------------------------------------------------------------------------------  
            IF @b_debug = 1  
            BEGIN  
               PRINT '>>>  @n_FromQty: ' + CONVERT(NVARCHAR(10), @n_FromQty)  
               PRINT '>>>  Qty In Loc: ' + CONVERT(NVARCHAR(10), @n_QtyInLoc)  
               PRINT '>>>  Qty To Replen: ' + CONVERT(NVARCHAR(10), @n_QtyToReplen)  
            END  
  
            IF @n_FromQty > 0  
            BEGIN  
  
               SELECT @c_Packkey = PACK.PackKey,  
                      @c_UOM = PACK.PackUOM3  
               FROM SKU  WITH (NOLOCK)  
               JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.Packkey)  
               WHERE SKU.StorerKey = @c_CurrentStorer  
               AND   SKU.Sku = @c_CurrentSku  
  
              INSERT #REPLENISHMENT  
                     (  ReplenishmentGrp  
                     ,  StorerKey  
                     ,  SKU  
                     ,  FromLOC  
                     ,  ToLOC  
                     ,  Lot  
                     ,  Id  
                     ,  Qty  
                     ,  UOM  
                     ,  PackKey  
                     ,  Priority  
                     ,  QtyMoved  
                     ,  QtyInPickLOC  
                     )  
               VALUES(  
                        @c_ReplenishmentGrp  
                     ,  @c_CurrentStorer  
                     ,  @c_CurrentSku  
                     ,  @c_FromLoc  
                     ,  @c_CurrentLOC  
                     ,  @c_FromLot  
                     ,  @c_FromID  
                     ,  @n_FromQty  
                     ,  @c_UOM  
                     ,  @c_Packkey  
                     ,  @c_CurrentPriority  
                     ,  0  
                     ,  0  
                     )  
               SET @n_Row = @n_Row + 1  
  
            END  
  
            NEXT_CANDIDATE:  
            FETCH NEXT FROM CUR_REPLEN INTO  @c_FromLoc  
                                          ,  @c_FromID  
                                          ,  @n_OnHandQty  
         END  
         NEXT_LOT:  
         IF CURSOR_STATUS( 'LOCAL' , 'CUR_REPLEN') IN (0, 1)  
         BEGIN  
            CLOSE CUR_REPLEN  
            DEALLOCATE CUR_REPLEN  
         END  
         SET @n_GroupTypePrev = @n_GroupType  
         FETCH NEXT FROM CUR_LOT INTO @c_FromLot  
                                    , @n_GroupType  
                                    , @n_QtyToReplen  
                                    , @c_SortColumn  
              -- , @n_RowNo  
  
      END  
      NEXT_SKUxLOC:  
      IF CURSOR_STATUS( 'LOCAL' , 'CUR_LOT') IN (0, 1)  
      BEGIN  
         CLOSE CUR_LOT  
         DEALLOCATE CUR_LOT  
      END  
      SET @n_GroupTypePrev = ''  
      FETCH NEXT FROM CUR_SKUxLOC INTO @c_CurrentPriority  
                                    ,  @c_CurrentStorer  
                                    ,  @c_CurrentSku  
                                    ,  @c_CurrentLoc  
                                    ,  @n_QtyExpected  
                                    ,  @n_Qty  
                                    ,  @n_QtyPicked  
                                    ,  @n_QtyAllocated  
                                    ,  @n_QtyLocationLimit  
                                    ,  @n_QtyLocationMinimum  
                                    ,  @n_CaseCnt  
                                    ,  @n_Pallet  
                                    ,  @c_LocationType  
   END  
   CLOSE CUR_SKUxLOC  
   DEALLOCATE CUR_SKUxLOC  
  
   IF @n_Continue=1 OR @n_Continue=2  
   BEGIN  
      /* Update the column QtyInPickLOC in the Replenishment Table */  
      UPDATE #REPLENISHMENT  
      SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked  
      FROM  SKUxLOC WITH (NOLOCK)  
      WHERE #REPLENISHMENT.StorerKey = SKUxLOC.StorerKey  
      AND   #REPLENISHMENT.Sku = SKUxLOC.Sku  
   END  
  
   WHILE @@TRANCOUNT > 0  
   BEGIN  
      COMMIT TRAN  
   END  
  
   SELECT @n_Row = COUNT(1) FROM #REPLENISHMENT  
  
   IF ISNULL(@n_Row,0) = 0  
   BEGIN  
      GOTO QUIT  
   END  
  
   IF @n_Continue=1 OR @n_Continue=2  
   BEGIN  
      BEGIN TRAN  
  
      EXECUTE nspg_GetKey  
               'REPLENISHKEY'  
            ,  10  
            ,  @c_ReplenishmentKey  OUTPUT  
            ,  @b_success           OUTPUT  
            ,  @n_err               OUTPUT  
            ,  @c_errmsg            OUTPUT  
            ,  0  
            ,  @n_Row  
  
      IF NOT @b_success = 1  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 63529   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': Fail to get REPLENISHKEY. (isp_ReplenishmentRpt_BatchRefill_15)'  
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT  
      END  
  
      COMMIT TRAN  
   END  
  
  
   IF @n_Continue=1 OR @n_Continue=2  
   BEGIN  
      /* Insert Into Replenishment Table Now */  
  
      --SET @n_ReplenishmentKey = CONVERT(INT, @c_ReplenishmentKey)  
      BEGIN TRAN  
  
      INSERT REPLENISHMENT  
         (  
            Replenishmentgroup  
         ,  ReplenishmentKey  
         ,  StorerKey  
         ,  Sku  
         ,  FromLoc  
         ,  ToLoc  
         ,  Lot  
         ,  Id  
         ,  Qty  
         ,  UOM  
         ,  PackKey  
         ,  Confirmed  
         )  
      SELECT  
            'IDS'  
         ,  RIGHT ( '000000000' + LTRIM(RTRIM(STR( CAST(@c_ReplenishmentKey AS INT) +  
                                         (SELECT COUNT(DISTINCT RowRef)  
                                          FROM #REPLENISHMENT AS RANK  
                                          WHERE RANK.RowRef < MIN(R.RowRef)  
                                          )  
                                         ))),10)  
         ,  R.StorerKey  
         ,  R.Sku  
         ,  R.FromLoc  
         ,  R.ToLoc  
         ,  R.Lot  
         ,  R.Id  
         ,  SUM(R.Qty)  
         ,  R.UOM  
         ,  R.PackKey  
         ,  'N'  
      FROM #REPLENISHMENT R  
      GROUP BY ReplenishmentGrp  
            ,  StorerKey  
            ,  SKU  
            ,  FromLOC  
            ,  ToLOC  
            ,  Lot  
            ,  Id  
            --,  Qty  
            ,  UOM  
            ,  PackKey  
            ,  Priority  
            ,  QtyMoved  
            ,  QtyInPickLOC  
  
      IF @n_err <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET  @n_err = 63531   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)  
                       + ': Insert into Replenishment table failed. (isp_ReplenishmentRpt_BatchRefill_15)'  
       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         GOTO QUIT  
      END  
      COMMIT TRAN  
  
      -- End Insert Replenishment  
   END  
  
QUIT:
   IF @c_FuncType IN ( '', 'P' )                                     --(Wan04)                                             
   BEGIN     
      --(Wan02) - START  
      --   SELECT Code  
      --         ,Storerkey  
      --   INTO #TMP_CODELKUP  
      --   FROM CODELKUP WITH (NOLOCK)  
      --   WHERE Listname = 'REPORTCFG'  
      --   AND   Long = 'r_replenishment_report15'  
      --   AND   (Short <> 'Y' OR Short IS NULL)  

      CREATE TABLE #TMP_REPLRPT  
            (  ReplenishmentGroup   NVARCHAR(10)   NULL  
            ,  ReplenishmentKey     NVARCHAR(10)   NULL  
            ,  StorerKey            NVARCHAR(15)   NULL  
            ,  Sku                  NVARCHAR(20)   NULL  
            ,  Descr                NVARCHAR(60)   NULL  
            ,  Lot                  NVARCHAR(10)   NULL  
            ,  FromLoc              NVARCHAR(10)   NULL  
            ,  ToLoc                NVARCHAR(10)   NULL  
            ,  Id                   NVARCHAR(18)   NULL  
   --         ,  ReplQtyCS            FLOAT          NULL  DEFAULT (0)  
   --         ,  ReplQtyEA            FLOAT          NULL  DEFAULT (0)   
            ,  PackKey              NVARCHAR(10)   NULL  
            ,  Priority             NVARCHAR(10)   NULL  
            ,  PutawayZone          NVARCHAR(10)   NULL  
            ,  CaseCnt              FLOAT          NULL  DEFAULT (0)  
            ,  PackUOM1             NVARCHAR(10)   NULL  
            ,  PackUOM3             NVARCHAR(10)   NULL  
   --         ,  QtyAvailableCS       FLOAT          NULL  DEFAULT (0)  
   --         ,  QtyAvailableEA       FLOAT          NULL  DEFAULT (0)  
            ,  ReplQty              INT            NULL  DEFAULT (0)  
            ,  QtyAvailable         INT            NULL  DEFAULT (0)  
            ,  LocQtyAvailable      INT            NULL  DEFAULT (0) --(Wan03)
            ,  RemoveID             INT            NULL  DEFAULT (0) 
            ,  GroupByLoc           INT            NULL  DEFAULT (0) --(Wan03)

            ,  ExchgSkuNQtyUsedPOS  INT            NULL  DEFAULT (0) --(Wan03)
            ,  IncreaseFontSize      INT            NULL  DEFAULT (0) --(Wan03)
            )  
      --(Wan02) - END 

   --(Wan02) - START
      IF @c_Zone02 = 'ALL'  
      BEGIN  
         --(Wan02) - START  
         INSERT INTO #TMP_REPLRPT  
               (  ReplenishmentGroup      
               ,  ReplenishmentKey        
               ,  StorerKey              
               ,  Sku                    
               ,  Descr                   
               ,  Lot                     
               ,  FromLoc                
               ,  ToLoc     
               ,  Id                
               ,  PackKey                 
               ,  Priority                
               ,  PutawayZone             
               ,  CaseCnt                 
               ,  PackUOM1                
               ,  PackUOM3                
               ,  ReplQty                 
               ,  QtyAvailable            
               )   
         --(Wan02) - END  
         SELECT  R.ReplenishmentGroup  
               , R.ReplenishmentKey    
               , R.StorerKey  
               , R.Sku  
               , SKU.Descr  
               , R.Lot       
               , R.FromLoc  
               , R.ToLoc  
               , R.Id   
   --            , ReplQtyCS = FLOOR(SUM(R.Qty) / ISNULL(PK.CaseCnt,1))                                                 --(Wan02)  
   --            , ReplQtyEA = SUM(R.Qty) % CONVERT(INT, ISNULL(PK.CaseCnt,1))                                          --(Wan02)  
               , R.PackKey  
               , R.Priority  
               , PutawayZone = UPPER(L2.PutawayZone)  
               , PK.CaseCnt  
               , PK.PackUOM1  
               , PK.PackUOM3  
   --            , QtyAvailableCS = FLOOR(SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) / ISNULL(PK.CaseCnt,1))       --(Wan02)  
   --            , QtyAvailableEA = SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) % CONVERT(INT, ISNULL(PK.CaseCnt,1))--(Wan02)  
               , ReplQty = SUM(R.Qty)                                                                 --(Wan01)  
               , QtyAvailable =  SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked)                      --(Wan01)  
         FROM  REPLENISHMENT R  with (NOLOCK) 
         JOIN  SKU  SKU  WITH (NOLOCK) ON (R.Storerkey = SKU.Storerkey) AND (R.Sku = SKU.Sku)  
         JOIN  PACK PK   WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)  
         JOIN  LOC  L1   WITH (NOLOCK) ON (R.ToLoc = L1.Loc)  
         JOIN  LOC  L2   WITH (NOLOCK) ON (R.FromLoc = L2.Loc)  
         JOIN  LOTxLOCxID   LLT WITH (NOLOCK) ON (R.Lot = LLT.Lot) AND (R.FromLoc = LLT.Loc AND R.ID = LLT.ID)  
         WHERE(L1.Facility = @c_Zone01)  
         AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  
         AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')                               --(Wan04)
         AND  (R.confirmed = 'N')  
         GROUP BY R.ReplenishmentGroup  
               ,  R.ReplenishmentKey  
               ,  R.StorerKey  
               ,  R.Sku  
               ,  SKU.Descr  
               ,  R.Lot  
               ,  R.FromLoc  
               ,  R.ToLoc  
               ,  R.Id  
               ,  R.PackKey  
               ,  R.Priority  
               ,  L2.PutawayZone  
               ,  PK.CaseCnt  
               ,  PK.PackUOM1  
               ,  PK.PackUOM3  
         ORDER BY MIN(L2.PutawayZone)      
               ,  R.FromLoc              
               ,  R.Storerkey             
               ,  R.Sku                   
      END  
      ELSE  
      BEGIN  
         --(Wan02) - START  
         INSERT INTO #TMP_REPLRPT  
               (  ReplenishmentGroup      
               ,  ReplenishmentKey        
               ,  StorerKey              
               ,  Sku                    
               ,  Descr                   
               ,  Lot                     
               ,  FromLoc                
               ,  ToLoc                   
               ,  Id                  
               ,  PackKey                 
               ,  Priority                
               ,  PutawayZone             
               ,  CaseCnt                 
               ,  PackUOM1                
               ,  PackUOM3                
               ,  ReplQty                 
               ,  QtyAvailable            
               )   
         --(Wan02) - END  
         SELECT  R.ReplenishmentGroup  
               , R.ReplenishmentKey                                                  
               , R.StorerKey  
               , R.Sku  
               , SKU.Descr  
               , R.Lot        
               , R.FromLoc  
               , R.ToLoc  
               , R.Id    
   --            , ReplQtyCS = FLOOR(SUM(R.Qty) / ISNULL(PK.CaseCnt,1))                                                    --(Wan02)  
   --            , ReplQtyEA = SUM(R.Qty) % CONVERT(INT, ISNULL(PK.CaseCnt,1))                                             --(Wan02)  
               , R.PackKey  
               , R.Priority  
               , PutawayZone = UPPER(L2.PutawayZone)  
               , PK.CaseCnt  
               , PK.PackUOM1  
               , PK.PackUOM3  
   --            , QtyAvailableCS = FLOOR(SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) / ISNULL(PK.CaseCnt,1))          --(Wan02)  
   --            , QtyAvailableEA = SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked) % CONVERT(INT, ISNULL(PK.CaseCnt,1))   --(Wan02)  
               , ReplQty = SUM(R.Qty)                                                                 --(Wan01)  
               , QtyAvailable =  SUM(LLT.Qty - LLT.QtyAllocated - LLT.QtyPicked)                      --(Wan01)  
         FROM  REPLENISHMENT R with (NOLOCK)  
         JOIN  SKU  SKU  WITH (NOLOCK) ON (R.Storerkey = SKU.Storerkey) AND (R.Sku = SKU.Sku)  
         JOIN  PACK PK   WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)  
         JOIN  LOC  L1   WITH (NOLOCK) ON (R.ToLoc = L1.Loc)  
         JOIN  LOC  L2   WITH (NOLOCK) ON (R.FromLoc = L2.Loc)  
         JOIN  LOTxLOCxID   LLT WITH (NOLOCK) ON (R.Lot = LLT.Lot) AND (R.FromLoc = LLT.Loc AND R.ID = LLT.ID)  
         WHERE(L1.Facility = @c_Zone01)  
         AND  (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')  
         AND  (R.ReplenishmentGroup = @c_ReplGrp OR @c_ReplGrp = 'ALL')                               --(Wan04)
         AND  (R.confirmed = 'N')  
         AND  L1.PutawayZone IN (@c_Zone02,@c_Zone03,@c_Zone04,@c_Zone05,@c_Zone06,@c_Zone07,@c_Zone08,@c_Zone09,@c_Zone10,@c_Zone11,@c_Zone12)  
         GROUP BY R.ReplenishmentGroup  
               ,  R.ReplenishmentKey  
               ,  R.StorerKey  
               ,  R.Sku  
               ,  SKU.Descr  
               ,  R.Lot  
               ,  R.FromLoc  
               ,  R.ToLoc  
               ,  R.Id  
               ,  R.PackKey  
               ,  R.Priority  
               ,  L2.PutawayZone  
               ,  PK.CaseCnt  
               ,  PK.PackUOM1  
               ,  PK.PackUOM3  
         ORDER BY MIN(L2.PutawayZone)      
               ,  R.FromLoc              
               ,  R.Storerkey            
               ,  R.Sku                    
      END  
 
      UPDATE #TMP_REPLRPT  
      SET Replenishmentkey = 'LFL'  
         ,Lot = ''  
         ,ID  = ''  
         ,LocQtyAvailable = SKUxLOC.Qty - SKUxLOC.QtyAllocated - SKUxLOC.QtyPicked        --(Wan03)
         ,GroupByLoc = 1
      FROM #TMP_REPLRPT  
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Storerkey = #TMP_REPLRPT.Storerkey) 
      JOIN SKUxLOC  WITH (NOLOCK) ON (#TMP_REPLRPT.Storerkey = SKUxLOC.Storerkey) 
                                    AND(#TMP_REPLRPT.Sku = SKUxLOC.Sku)
                                    AND(#TMP_REPLRPT.FromLoc = SKUxLOC.Loc)
      WHERE CODELKUP.Listname = 'REPORTCFG'  
      AND   CODELKUP.Code = 'GroupByLoc'  
      AND   CODELKUP.Long = 'r_replenishment_report15'  
      AND   (Short <> 'N' OR Short IS NULL)  

      UPDATE #TMP_REPLRPT  
      SET RemoveID = 1  
      FROM #TMP_REPLRPT  
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Storerkey = #TMP_REPLRPT.Storerkey)  
      WHERE CODELKUP.Listname = 'REPORTCFG'  
      AND   CODELKUP.Code = 'RemoveID'  
      AND   CODELKUP.Long = 'r_replenishment_report15'  
      AND   (Short <> 'N' OR Short IS NULL)  
  
      --(Wan03) - START 
      UPDATE #TMP_REPLRPT  
      SET ExchgSkuNQtyUsedPOS = 1  
      FROM #TMP_REPLRPT  
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Storerkey = #TMP_REPLRPT.Storerkey)  
      WHERE CODELKUP.Listname = 'REPORTCFG'  
      AND   CODELKUP.Code = 'ExchgSkuNQtyUsedPOS'  
      AND   CODELKUP.Long = 'r_replenishment_report15'  
      AND   (Short <> 'N' OR Short IS NULL)
    
      UPDATE #TMP_REPLRPT  
      SET IncreaseFontSize = 1  
      FROM #TMP_REPLRPT  
      JOIN CODELKUP WITH (NOLOCK) ON (CODELKUP.Storerkey = #TMP_REPLRPT.Storerkey)  
      WHERE CODELKUP.Listname = 'REPORTCFG'  
      AND   CODELKUP.Code = 'IncreaseFontSize'  
      AND   CODELKUP.Long = 'r_replenishment_report15'  
      AND   (Short <> 'N' OR Short IS NULL)      
      --(Wan03) - END
     
      SELECT   ReplenishmentGroup = ISNULL(ReplenishmentGroup,'')      
            ,  ReplenishmentKey   = ISNULL(ReplenishmentKey ,'')        
            ,  StorerKey          = ISNULL(StorerKey,'')               
            ,  Sku                = ISNULL(Sku,'')                     
            ,  Descr              = ISNULL(Descr ,'')                   
            ,  Lot                = ISNULL(Lot,'')                      
            ,  FromLoc            = ISNULL(FromLoc,'')                 
            ,  ToLoc              = ISNULL(ToLoc,'')                    
            ,  Id                 = ISNULL(Id,'')                   
            ,  ReplQtyCS          = CASE WHEN ISNULL(CaseCnt,0) > 0 THEN FLOOR(ISNULL(SUM(ReplQty),0) / ISNULL(CaseCnt,0))   
                                          ELSE 0 END              
            ,  ReplQtyEA          = CASE WHEN ISNULL(CaseCnt,0) > 0 THEN ISNULL(SUM(ReplQty),0) % CONVERT(INT, ISNULL(CaseCnt,0))  
                                          ELSE ISNULL(SUM(ReplQty),0) END            
            ,  PackKey            = ISNULL(PackKey,'')                  
            ,  Priority           = ISNULL(Priority,'')                 
            ,  PutawayZone        = ISNULL(PutawayZone,'')              
            ,  CaseCnt            = ISNULL(CaseCnt,0)                
            ,  PackUOM1           = ISNULL(PackUOM1,'')                 
            ,  PackUOM3           = ISNULL(PackUOM3,'')                 
            ,  QtyAvailableCS     = CASE WHEN ISNULL(GroupByLoc,0) = 1 AND ISNULL(CaseCnt,0) > 0 
                                          THEN FLOOR(ISNULL(LocQtyAvailable,0) / ISNULL(CaseCnt,0)) 
                                          WHEN ISNULL(GroupByLoc,0) = 0 AND ISNULL(CaseCnt,0) > 0 
                                          THEN FLOOR(ISNULL(SUM(QtyAvailable),0) / ISNULL(CaseCnt,0))   
                                          ELSE 0 END       
            ,  QtyAvailableEA     = CASE WHEN ISNULL(GroupByLoc,0) = 1 AND ISNULL(CaseCnt,0) > 0 
                                          THEN ISNULL(LocQtyAvailable,0) % CONVERT(INT, ISNULL(CaseCnt,0))
                                          WHEN ISNULL(GroupByLoc,0) = 0 AND ISNULL(CaseCnt,0) > 0 
                                          THEN ISNULL(SUM(QtyAvailable),0) % CONVERT(INT, ISNULL(CaseCnt,0))  
                                          WHEN ISNULL(GroupByLoc,0) = 1 AND ISNULL(CaseCnt,0) = 0 
                                          THEN ISNULL(LocQtyAvailable,0)
                                          ELSE ISNULL(SUM(QtyAvailable),0) END           
            ,  ReplQty            = ISNULL(SUM(ReplQty),0)                  
            ,  QtyAvailable       = CASE WHEN ISNULL(GroupByLoc,0) = 1 THEN ISNULL(LocQtyAvailable,0)  ELSE ISNULL(SUM(QtyAvailable),0) END           
            ,  RemoveID           = ISNULL(RemoveID,0)
            ,  ExchgSkuNQtyUsedPOS= ISNULL(ExchgSkuNQtyUsedPOS,'')     --(Wan03)  
            ,  IncreaseFontSize    = ISNULL(IncreaseFontSize,'')       --(Wan03) 
      FROM #TMP_REPLRPT  
      GROUP BY ISNULL(ReplenishmentGroup,'')  
            ,  ISNULL(ReplenishmentKey,'')  
            ,  ISNULL(StorerKey,'')  
            ,  ISNULL(Sku,'')  
            ,  ISNULL(Descr,'')  
            ,  ISNULL(Lot,'')  
            ,  ISNULL(FromLoc,'')  
            ,  ISNULL(ToLoc,'')  
            ,  ISNULL(Id,'')  
            ,  ISNULL(PackKey,'')  
            ,  ISNULL(Priority,'')  
            ,  ISNULL(PutawayZone,'')  
            ,  ISNULL(CaseCnt,0)  
            ,  ISNULL(PackUOM1,'')  
            ,  ISNULL(PackUOM3,'')  
            ,  ISNULL(RemoveID,0)  
            ,  ISNULL(LocQtyAvailable,0)                             --(Wan03) 
            ,  ISNULL(GroupByLoc,0)                                  --(Wan03) 
            ,  ISNULL(ExchgSkuNQtyUsedPOS,'')                        --(Wan03) 
            ,  ISNULL(IncreaseFontSize,'')                           --(Wan03) 
      ORDER BY MIN(ISNULL(PutawayZone,''))  
            ,  ISNULL(FromLoc,'')  
            ,  ISNULL(Storerkey,'')  
            ,  ISNULL(Sku,'')  
                                                                               

      --(Wan02) - END  
   END  
   --(Wan04) - END  

   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN  
   END  
  
   IF @n_Continue=3  -- Error Occured - Process AND Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ReplenishmentRpt_BatchRefill_15'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END

GO