SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispDesigualWaveFP6                                      */
/* Creation Date: 29-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22617 - [CN] Desigual_WMS_AllocationStrategy            */
/*          SkipPreallocation = '1'                                     */
/*          Full UCC Control                                            */
/*          Allocate from BULK Location                                 */
/*          Pick FULL PALLET from PALLET Location                       */
/*                                                                      */
/* Called By:                                                           */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 29-May-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispDesigualWaveFP6]
     @c_WaveKey            NVARCHAR(10)
   , @c_WaveType           NVARCHAR(10) = ''
   , @c_Facility           NVARCHAR(5)  = ''
   , @c_Storerkey          NVARCHAR(15) = ''
   , @c_Sku                NVARCHAR(20) = ''
   , @c_Lottable01         NVARCHAR(18) = ''      
   , @c_Lottable02         NVARCHAR(18) = ''   
   , @c_Lottable03         NVARCHAR(18) = ''
   , @dt_Lottable04        DATETIME   
   , @dt_Lottable05        DATETIME
   , @c_Lottable06         NVARCHAR(30) = ''
   , @c_Lottable07         NVARCHAR(30) = ''
   , @c_Lottable08         NVARCHAR(30) = ''
   , @c_Lottable09         NVARCHAR(30) = ''
   , @c_Lottable10         NVARCHAR(30) = ''
   , @c_Lottable11         NVARCHAR(30) = ''
   , @c_Lottable12         NVARCHAR(30) = ''
   , @dt_Lottable13        DATETIME  
   , @dt_Lottable14        DATETIME   
   , @dt_Lottable15        DATETIME
   , @n_QtyLeftToFullfill  INT      = 0   OUTPUT
   , @b_Success            INT            OUTPUT  
   , @n_Err                INT            OUTPUT  
   , @c_ErrMsg             NVARCHAR(255)  OUTPUT  
   , @b_Debug              INT      = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1

         , @c_LocationType       NVARCHAR(10) = 'OTHER'      
         , @c_LocationCategory   NVARCHAR(10) = 'BULK'
         , @c_LocationHandlingPL NVARCHAR(10) = '1'
         , @c_UOM                NVARCHAR(10) = '6'
         , @c_PickMethod         NVARCHAR(10) = 'P'

         , @dt_Lottable13_1      DATETIME     
         , @dt_Lottable13_2      DATETIME

         , @n_TotalExpiryDay     INT   = 0
         , @n_TotalOrderQty      INT   = 0
         , @n_IDQty              INT   = 0

         , @c_Lot                NVARCHAR(10) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @n_QtyAvailable       INT          = 0

         , @n_UCC_RowRef         INT          = 0  
         , @c_UCCNo              NVARCHAR(20) = ''
         , @n_UCCQty             INT          = 0

         , @n_RowID                  INT          = 0
         , @n_Status                 INT          = 0
         , @c_Loadkey                NVARCHAR(10) = ''
         , @c_Orderkey               NVARCHAR(10) = ''
         , @c_OrderLineNumber        NVARCHAR(5)  = ''
         , @c_PickDetailkey          NVARCHAR(10) = ''
         , @c_PackKey                NVARCHAR(10) = ''
         , @n_UOMQty                 INT          = 0
         , @n_Shelflife              INT          = 0
         , @n_OrderQty               INT          = 0
         , @n_QtyToInsert            INT          = 0
         , @n_NoOfSKU                INT          = 0
         , @n_TotalQty               INT          = 0
         , @c_WaveNo                 NVARCHAR(10) = ''
         --, @n_LotAvailableQty        INT          = 0
         --, @n_FacLotAvailQty         INT          = 0 

         , @c_SQL                NVARCHAR(4000) = ''
         , @c_SQLParms           NVARCHAR(4000) = ''

         , @CUR_LOAD             CURSOR
         , @CUR_LI               CURSOR
         , @CUR_UCC              CURSOR
         , @CUR_OD               CURSOR

   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF OBJECT_ID('tempdb..#LOCxID','U') IS NOT NULL
   BEGIN
      DROP TABLE #LOCxID;
   END

   CREATE TABLE #LOCxID
      (  RowID          INT            IDENTITY(1,1) PRIMARY KEY
      ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  Qty            INT            NOT NULL DEFAULT(0)
      )

   IF OBJECT_ID('tempdb..#LOTxLOCxIDxUCC','U') IS NOT NULL
   BEGIN
      DROP TABLE #LOTxLOCxIDxUCC;
   END

   CREATE TABLE #LOTxLOCxIDxUCC
      (  RowID          INT            IDENTITY(1,1) PRIMARY KEY
      ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  QtyAvailable   INT            NOT NULL DEFAULT(0)
      ,  ExpiryDate     DATETIME       NULL
      ,  UCCNo          NVARCHAR(20)   NOT NULL DEFAULT('')
      ,  UCCQty         INT            NOT NULL DEFAULT(0)
      ,  UCC_RowRef     INT            NOT NULL DEFAULT(0)
      ,  [Status]       NVARCHAR(10)   NOT NULL DEFAULT(0)
      )

   IF OBJECT_ID('tempdb..#ORDLINE','U') IS NOT NULL
   BEGIN
      DROP TABLE #ORDLINE;
   END

   CREATE TABLE #ORDLINE
      (  RowID             INT            IDENTITY(1,1) PRIMARY KEY
      ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  Loadkey           NVARCHAR(10)   NOT NULL DEFAULT('') 
      ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')
      ,  ShelfLife         NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  OrderQty          INT            NOT NULL DEFAULT(0)
      ,  [Status]          INT            NOT NULL DEFAULT(0)
      )
   
   SELECT @c_Packkey = S.Packkey
   FROM SKU S  WITH (NOLOCK) 
   WHERE Storerkey = @c_Storerkey
   AND Sku = @c_Sku

   IF ISNULL(@dt_Lottable13,'1900-01-01') = '1900-01-01'
   BEGIN
      SET @dt_Lottable13_1 = '1900-01-01'
      SET @dt_Lottable13_2 = NULL
   END
   ELSE
   BEGIN
      SET @dt_Lottable13_1 = CONVERT( NVARCHAR(10), @dt_Lottable13, 121 )
      SET @dt_Lottable13_2 = CONVERT( NVARCHAR(10), @dt_Lottable13, 121 )
   END
   
   SET @n_TotalExpiryDay = 0

   IF @b_debug IN (1,9)
   BEGIN
      PRINT '---------------------------------------'+ CHAR(13) +
            'Sub PICKCOde: ispDesigualWaveFP6'+ CHAR(13) +
            'Facility: ' + @c_Facility + CHAR(13) +
            'Storerkey: ' + @c_Storerkey + CHAR(13) +
            'SKU: ' + @c_SKU + CHAR(13) +
            'LocationType: ' + @c_LocationType + CHAR(13) +
            'LocationCategory: ' + @c_LocationCategory + CHAR(13) +
            'LocationHandlingPL: ' + @c_LocationHandlingPL + CHAR(13) +
            '@n_QtyLeftToFullFill: ' + CAST(@n_QtyLeftToFullFill AS VARCHAR) + CHAR(13) +
            '@c_Lottable01: ' + @c_Lottable01 + CHAR(13) +
            '@c_Lottable02: ' + @c_Lottable02 + CHAR(13) +
            '@c_Lottable03: ' + @c_Lottable03 + CHAR(13) +
            '@dt_Lottable04: ' + + CONVERT(VARCHAR(20),@dt_Lottable04, 106) + CHAR(13) + 
            '@c_Lottable06: ' + @c_Lottable06 + CHAR(13) +
            '@c_Lottable07: ' + @c_Lottable07 + CHAR(13) +
            '@c_Lottable08: ' + @c_Lottable08 + CHAR(13) +
            '@c_Lottable10: ' + @c_Lottable10 + CHAR(13) +
            '@c_Lottable09: ' + @c_Lottable09 + CHAR(13) +
            '@c_Lottable11: ' + @c_Lottable11 + CHAR(13) +
            '@c_Lottable12: ' + @c_Lottable12
   END

  ;WITH ORD AS
   (  SELECT Loadkey = ''
            ,OH.Orderkey
      FROM WAVE        WH WITH (NOLOCK)
      JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey  = WD.Wavekey
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      WHERE WH.Wavekey = @c_WaveKey
      AND OH.[Type] NOT IN ( 'M', 'I' ) 
      AND OH.DocType = 'N' 
      AND OH.SOStatus <> 'CANC'   
      AND OH.[Status] < '9' 
   )   

   INSERT INTO #ORDLINE
      (  Wavekey
      ,  Loadkey
      ,  Orderkey          
      ,  OrderLineNumber   
      ,  ShelfLife 
      ,  OrderQty                 
      )
   SELECT Wavekey = @c_WaveKey
         ,OH.Loadkey
         ,OD.Orderkey
         ,OD.OrderLineNumber
         ,0
         ,OrderQty = (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked))
   FROM ORD         OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   WHERE  OD.Storerkey = @c_Storerkey
      AND OD.Sku = @c_Sku  
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked)) > 0
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked)) <= @n_QtyLeftToFullFill
      AND OD.Lottable01 = @c_Lottable01
      AND OD.Lottable02 = @c_Lottable02
      AND OD.Lottable03 = @c_Lottable03
      AND OD.Lottable04 = @dt_Lottable04
      AND OD.Lottable06 = @c_Lottable06
      AND OD.Lottable07 = @c_Lottable07
      AND OD.Lottable08 = @c_Lottable08
      AND OD.Lottable09 = @c_Lottable09
      AND OD.Lottable10 = @c_Lottable10
      AND OD.Lottable11 = @c_Lottable11
      AND OD.Lottable12 = @c_Lottable12
   ORDER BY OD.Loadkey
         ,  OD.Orderkey
         ,  OD.OrderLineNumber

   IF @@ROWCOUNT = 0 
   BEGIN
      GOTO QUIT_SP
   END
   
   IF @b_debug IN (2,9)
   BEGIN
      SELECT *
      FROM #ORDLINE 
      ORDER BY RowID
   END
   
   SELECT TOP 1 @n_TotalOrderQty = SUM(OL.OrderQty)
   FROM #ORDLINE OL
   GROUP BY OL.Wavekey
         ,  OL.Loadkey
   ORDER BY SUM(OL.OrderQty) DESC

   SET @c_SQL = N'INSERT INTO #LOCxID ( Loc, ID, Qty )' + CHAR(13) + 
   + ' SELECT LLI.Loc, LLI.ID' + CHAR(13) + 
   + ' ,Qty = SUM(LLI.Qty)' + CHAR(13) + 
   + ' FROM LOTxLOCxID LLI  WITH (NOLOCK)' + CHAR(13) + 
   + ' JOIN LOT             WITH (NOLOCK) ON LLI.Lot = LOT.Lot' + CHAR(13) + 
   + ' JOIN LOC             WITH (NOLOCK) ON LLI.Loc = LOC.Loc AND LOC.[Status] = ''OK''' + CHAR(13) + 
   + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot' + CHAR(13) +
   --+ ' JOIN UCC             WITH (NOLOCK) ON LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc AND LLI.ID = UCC.ID' + CHAR(13) + 
   + ' CROSS APPLY (SELECT MIN(Status) AS MinStatus, MAX(Status) AS MaxStatus' + CHAR(13) + 
   + '              FROM UCC (NOLOCK) ' + CHAR(13) + 
   + '              WHERE LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc AND LLI.ID = UCC.ID) AS U' + CHAR(13) + 
   + ' WHERE LLI.Storerkey = @c_Storerkey' + CHAR(13) + 
   + ' AND   LLI.Sku       = @c_Sku' + CHAR(13) + 
   + CASE WHEN ISNULL(@c_Lottable01,'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01' END
   + CASE WHEN ISNULL(@c_Lottable02,'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02' END
   + CASE WHEN ISNULL(@c_Lottable03,'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03' END
   + CASE WHEN ISNULL(@dt_Lottable04,'1900-01-01') = '1900-01-01' THEN '' ELSE ' AND LA.Lottable04 = @dt_Lottable04' END 
   + CASE WHEN ISNULL(@c_Lottable06,'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06' END
   + CASE WHEN ISNULL(@c_Lottable07,'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07' END
   + CASE WHEN ISNULL(@c_Lottable08,'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08' END
   + CASE WHEN ISNULL(@c_Lottable09,'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09' END
   + CASE WHEN ISNULL(@c_Lottable10,'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10' END
   + CASE WHEN ISNULL(@c_Lottable11,'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11' END
   + CASE WHEN ISNULL(@c_Lottable12,'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12' END
   +' AND   LOC.Facility  = @c_Facility' + CHAR(13) + 
   +' AND   LOC.LocationCategory = @c_LocationCategory' + CHAR(13) + 
   +' AND   LOC.LocationHandling IN ( @c_LocationHandlingPL ) ' + CHAR(13) + 
   +' AND   LOC.LocationType = @c_LocationType' + CHAR(13) + 
   +' GROUP BY LLI.Loc, LLI.ID' + CHAR(13) + 
   +' HAVING SUM(LLI.Qty) <= @n_TotalOrderQty'  + CHAR(13) +  
   +' AND    SUM(LLI.QtyAllocated + LLI.QtyPicked + LLI.QtyReplen) = 0' + CHAR(13) + 
   +' AND    COUNT(DISTINCT(LLI.Sku)) = 1' + CHAR(13) + 
   +' AND    COUNT(DISTINCT LOT.[Status]) = 1 AND MIN(LOT.[Status]) = ''OK''' + CHAR(13) + 
   --+' AND    MIN(UCC.[Status]) >= ''1'' AND MAX(UCC.[Status]) < ''3''' + CHAR(13) + 
   +' AND    MIN(U.MinStatus) >= ''1'' AND MAX(U.MaxStatus) < ''3'' ' + CHAR(13) + 
   +' ORDER BY LLI.Loc, Qty'
   --PRINT @c_SQL
   SET @c_SQLParms= N' @c_Facility           NVARCHAR(5)'  
                  + ', @c_Storerkey          NVARCHAR(15)' 
                  + ', @c_Sku                NVARCHAR(20)' 
                  + ', @c_Lottable01         NVARCHAR(18)'     
                  + ', @c_Lottable02         NVARCHAR(18)'  
                  + ', @c_Lottable03         NVARCHAR(18)' 
                  + ', @dt_Lottable04        DATETIME' 
                  + ', @c_Lottable06         NVARCHAR(30)' 
                  + ', @c_Lottable07         NVARCHAR(30)' 
                  + ', @c_Lottable08         NVARCHAR(30)' 
                  + ', @c_Lottable09         NVARCHAR(30)' 
                  + ', @c_Lottable10         NVARCHAR(30)' 
                  + ', @c_Lottable11         NVARCHAR(30)' 
                  + ', @c_Lottable12         NVARCHAR(30)' 
                  + ', @c_LocationType       NVARCHAR(10)'      
                  + ', @c_LocationCategory   NVARCHAR(10)' 
                  + ', @c_LocationHandlingPL NVARCHAR(10)'
                  + ', @n_TotalOrderQty      INT'                                               
      
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms 
                     , @c_Facility           
                     , @c_Storerkey         
                     , @c_Sku               
                     , @c_Lottable01        
                     , @c_Lottable02        
                     , @c_Lottable03       
                     , @dt_Lottable04 
                     , @c_Lottable06        
                     , @c_Lottable07        
                     , @c_Lottable08        
                     , @c_Lottable09        
                     , @c_Lottable10        
                     , @c_Lottable11        
                     , @c_Lottable12        
                     , @c_LocationType            
                     , @c_LocationCategory 
                     , @c_LocationhandlingPL 
                     , @n_TotalOrderQty                                                                
          
   SET @CUR_LI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LI.Loc
       ,  LI.ID
       ,  LI.Qty
   FROM #LOCxID LI
      
   OPEN @CUR_LI

   FETCH NEXT FROM @CUR_LI INTO @c_Loc, @c_ID, @n_IDQty 

   WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFullFill > 0 AND @n_QtyLeftToFullFill >= @n_IDQty
   BEGIN
      SET @c_WaveNo = ''
      SELECT TOP 1 @c_WaveNo = OL.Wavekey                   
      FROM #ORDLINE    OL WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OL.Orderkey = OD.Orderkey 
                                       AND OL.OrderLineNumber = OD.OrderLineNumber
      WHERE OL.Wavekey = @c_Wavekey
      AND   OL.[Status] = 0
      GROUP BY OL.Wavekey
      HAVING SUM((OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked))) >= @n_IDQty
      ORDER BY OL.Wavekey

      IF @c_WaveNo = ''
      BEGIN
         GOTO NEXT_LOCxID
      END

      TRUNCATE TABLE #LOTxLOCxIDxUCC

      SET @c_SQL = N'INSERT INTO #LOTxLOCxIDxUCC ( Lot, Loc, ID, QtyAvailable, ExpiryDate, UCCNo, UCCQty, UCC_RowRef, Status )'
      + ' SELECT LLI.Lot, LLI.Loc, LLI.ID'
      + ' ,QtyAvailable = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen'
      + ' ,ExpiryDate = LA.Lottable04'
      + ' ,UCC.UCCNo'
      + ' ,UCC.Qty'
      + ' ,UCC.UCC_RowRef'
      + ' ,UCC.[Status]'
      + ' FROM LOTxLOCxID LLI  WITH (NOLOCK)'
      + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot' 
      + ' JOIN UCC             WITH (NOLOCK) ON LLI.Lot = UCC.Lot AND LLI.Loc = UCC.Loc AND LLI.ID = UCC.ID'
      + ' WHERE LLI.Storerkey = @c_Storerkey'
      + ' AND   LLI.Sku       = @c_Sku'
      + ' AND   LLI.Loc       = @c_Loc'
      + ' AND   LLI.ID        = @c_ID'
      + CASE WHEN ISNULL(@c_Lottable01,'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01' END
      + CASE WHEN ISNULL(@c_Lottable02,'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02' END
      + CASE WHEN ISNULL(@c_Lottable03,'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03' END
      + CASE WHEN ISNULL(@dt_Lottable04,'1900-01-01') = '1900-01-01' THEN '' ELSE ' AND LA.Lottable04 = @dt_Lottable04' END
      + CASE WHEN ISNULL(@c_Lottable06,'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06' END
      + CASE WHEN ISNULL(@c_Lottable07,'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07' END
      + CASE WHEN ISNULL(@c_Lottable08,'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08' END
      + CASE WHEN ISNULL(@c_Lottable09,'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09' END
      + CASE WHEN ISNULL(@c_Lottable10,'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10' END
      + CASE WHEN ISNULL(@c_Lottable11,'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11' END
      + CASE WHEN ISNULL(@c_Lottable12,'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12' END
      + ' ORDER BY LLI.Loc, LLI.ID, LLI.Lot'

      SET @c_SQLParms= N' @c_Storerkey          NVARCHAR(15)' 
                     + ', @c_Sku                NVARCHAR(20)' 
                     + ', @c_Loc                NVARCHAR(10)' 
                     + ', @c_ID                 NVARCHAR(18)' 
                     + ', @c_Lottable01         NVARCHAR(18)'     
                     + ', @c_Lottable02         NVARCHAR(18)'  
                     + ', @c_Lottable03         NVARCHAR(18)' 
                     + ', @dt_Lottable04        DATETIME' 
                     + ', @c_Lottable06         NVARCHAR(30)' 
                     + ', @c_Lottable07         NVARCHAR(30)' 
                     + ', @c_Lottable08         NVARCHAR(30)' 
                     + ', @c_Lottable09         NVARCHAR(30)' 
                     + ', @c_Lottable10         NVARCHAR(30)' 
                     + ', @c_Lottable11         NVARCHAR(30)' 
                     + ', @c_Lottable12         NVARCHAR(30)' 

      EXEC sp_ExecuteSQL  @c_SQL
                        , @c_SQLParms 
                        , @c_Storerkey         
                        , @c_Sku 
                        , @c_Loc       
                        , @c_ID                                        
                        , @c_Lottable01        
                        , @c_Lottable02        
                        , @c_Lottable03   
                        , @dt_Lottable04     
                        , @c_Lottable06        
                        , @c_Lottable07        
                        , @c_Lottable08        
                        , @c_Lottable09        
                        , @c_Lottable10        
                        , @c_Lottable11        
                        , @c_Lottable12       
                 
      IF NOT EXISTS (SELECT 1                    
                     FROM #LOTxLOCxIDxUCC UCC
                     GROUP BY UCC.Loc, UCC.ID
                     HAVING SUM(UCC.UCCQty) = @n_IDQty
                     AND MIN(UCC.[Status]) >= 1 AND MAX(UCC.[Status]) < '3'
                     )
      BEGIN
         GOTO NEXT_LOCxID
      END

      IF NOT EXISTS (SELECT 1                    
                     FROM #LOTxLOCxIDxUCC UCC
                     GROUP BY UCC.Lot, UCC.Loc, UCC.ID, UCC.QtyAvailable
                     HAVING UCC.QtyAvailable = SUM(UCC.UCCQty)
                     AND MIN(UCC.[Status]) >= 1 AND MAX(UCC.[Status]) < '3'
                     )
      BEGIN
         GOTO NEXT_LOCxID
      END

      SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT UCC.Lot 
            ,UCC.Loc
            ,UCC.ID
            ,UCC.UCCNo
            ,UCC.UCCQty
            ,UCC.UCC_RowRef
      FROM #LOTxLOCxIDxUCC UCC
      ORDER BY UCC.RowID

      OPEN @CUR_UCC

      FETCH NEXT FROM @CUR_UCC INTO @c_Lot 
                                 ,  @c_Loc
                                 ,  @c_ID
                                 ,  @c_UCCNo
                                 ,  @n_UCCQty
                                 ,  @n_UCC_RowRef
   
      WHILE @@FETCH_STATUS <> -1 AND  @n_QtyLeftToFullFill > 0
      BEGIN

         SET @CUR_OD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OL.RowID
               ,OD.Orderkey
               ,OD.OrderLineNumber
               ,OrderQty = (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked ))
         FROM #ORDLINE    OL WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON OL.Orderkey = OD.Orderkey 
                                          AND OL.OrderLineNumber = OD.OrderLineNumber
         WHERE OL.Wavekey= @c_Wavekey
         AND OL.[Status] = 0
         AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )) > 0
         AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )) <= @n_QtyLeftToFullFill
         ORDER BY OL.RowID

         OPEN @CUR_OD
   
         FETCH NEXT FROM @CUR_OD INTO @n_RowID, @c_Orderkey, @c_OrderlineNumber, @n_OrderQty
       
         WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFullFill > 0 AND @n_UCCQty > 0
         BEGIN
            SET @n_Status = 0

            IF @n_OrderQty <= @n_UCCQty
            BEGIN 
               SET @n_QtyToInsert = @n_OrderQty
            END
            ELSE
            BEGIN
               SET @n_QtyToInsert = @n_UCCQty
            END

            IF @n_QtyToInsert > 0
            BEGIN
               ---- INSERT PICKDETAIL
               EXECUTE nspg_getkey  
                  'PickDetailKey'  
                  , 10  
                  , @c_PickDetailKey OUTPUT  
                  , @b_Success       OUTPUT  
                  , @n_Err           OUTPUT  
                  , @c_ErrMsg        OUTPUT  
                  
               IF @b_Success <> 1  
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 81210
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                 + ': Get PickDetailKey Failed. (ispDesigualWaveFP6)'
                  GOTO QUIT_SP
               END

               SET @n_UOMQty = @n_QtyToInsert

               IF @b_Debug IN (1,9)
               BEGIN
                  PRINT '----------------------------------------------------------------------'   + CHAR(13) +
                        'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
                        'OrderKey: ' + @c_OrderKey + CHAR(13) +
                        'OrderLineNumber: ' + @c_OrderLineNumber + CHAR(13) +
                        'OrderQty: ' + CAST(@n_OrderQty AS NVARCHAR) + CHAR(13) +
                        'QtyToInsert: ' + CAST(@n_QtyToInsert AS NVARCHAR) + CHAR(13) +
                        'SKU: ' + @c_SKU + CHAR(13) +
                        'PackKey: ' + @c_PackKey + CHAR(13) +
                        'Lot: ' + @c_Lot + CHAR(13) +
                        'Loc: ' + @c_Loc + CHAR(13) +
                        'ID: '  + @c_ID  + CHAR(13) +
                        'UOM: ' + @c_UOM + CHAR(13) +
                        'UOMQty: '+ CAST(@n_UOMQty AS NVARCHAR) + CHAR(13) +
                        'PickMethod: ' + @c_PickMethod + CHAR(13) +
                        'UCCNo: ' + @c_UCCNo + CHAR(13) +
                        'UCCQty: ' +CAST(@n_UCCQty AS NVARCHAR) + CHAR(13) +
                        'Lot04: ' + CONVERT( NVARCHAR(20), @dt_Lottable04, 121) + CHAR(13) +
                        '----------------------------------------------------------------------'
               END

               INSERT INTO PICKDETAIL (  
                     PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber,  
                     Lot, StorerKey, Sku, UOM, UOMQty, Qty, DropID,
                     Loc, Id, PackKey, CartonGroup, DoReplenish,  
                     replenishzone, doCartonize, Trafficcop, PickMethod,
                     Wavekey
                     ) 
               VALUES (  
                     @c_PickDetailKey, '', '', @c_OrderKey, @c_OrderLineNumber,  
                     @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UOMQty, @n_QtyToInsert, @c_UCCNo,
                     @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                     '', NULL, 'U', @c_PickMethod, 
                     @c_Wavekey
                     )  
                  
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 81220
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                 + ': Insert PickDetail Failed. (ispDesigualWaveFP6)'
                  GOTO QUIT_SP
               END

               IF EXISTS ( SELECT 1 
                           FROM UCC WITH (NOLOCK)
                           WHERE UCC_RowRef = @n_UCC_RowRef
                           AND [Status] <= '3'
                           )
               BEGIN
                  UPDATE UCC
                  SET [Status] = '3'
                     ,EditWho  = SUSER_NAME()
                     ,EditDate = GETDATE()
                  WHERE UCC_RowRef = @n_UCC_RowRef
                  AND [Status] <= '3'

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @n_Err = 81230
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                                    + ': Update UCC Failed. (ispDesigualWaveFP6)'
                     GOTO QUIT_SP
                  END
               END

               SET @n_OrderQty = @n_OrderQty - @n_QtyToInsert
               SET @n_UCCQty = @n_UCCQty - @n_QtyToInsert
               SET @n_QtyLeftToFullFill = @n_QtyLeftToFullFill - @n_QtyToInsert
            END

            IF @n_OrderQty <= 0 
            BEGIN
               SET @n_Status = 9
            END

            NEXT_ORDER:

            UPDATE #ORDLINE
               SET [Status] = @n_Status
            WHERE RowID = @n_RowID

            FETCH NEXT FROM @CUR_OD INTO @n_RowID, @c_Orderkey, @c_OrderlineNumber, @n_OrderQty 
         END

         CLOSE @CUR_OD
         DEALLOCATE @CUR_OD
      
         NEXT_UCC:
         FETCH NEXT FROM @CUR_UCC INTO @c_Lot 
                                    ,  @c_Loc
                                    ,  @c_ID
                                    ,  @c_UCCNo
                                    ,  @n_UCCQty 
                                    ,  @n_UCC_RowRef   
      END 
      CLOSE @CUR_UCC
      DEALLOCATE @CUR_UCC

      NEXT_LOCxID:
      FETCH NEXT FROM @CUR_LI INTO @c_Loc, @c_ID, @n_IDQty
   END
   CLOSE @CUR_LI
   DEALLOCATE @CUR_LI

QUIT_SP:
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispDesigualWaveFP6'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO