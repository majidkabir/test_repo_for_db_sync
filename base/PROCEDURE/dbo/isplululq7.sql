SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispLuLuLQ7                                              */
/* Creation Date: 2021-01-25                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-15651 - HK - Lululemon Relocation Project - Allocation  */
/*          Strategy CR                                                 */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-01-25  Wan      1.0   Created                                   */
/* 2021-07-19  Wan01    1.1   Fixed. Continue Next Record               */
/* 2021-08-12  Wan03    1.2   Performance Tune                          */ 
/* 2023-09-07  Michael  1.3   Extend #TMPALLOC.ID len to 18 (ML01)      */
/************************************************************************/
CREATE PROC [dbo].[ispLuLuLQ7]
     @c_WaveKey                     NVARCHAR(10)
   , @c_UOM                         NVARCHAR(10)
   , @c_LocationTypeOverride        NVARCHAR(10)
   , @c_LocationTypeOverRideStripe  NVARCHAR(10)
   , @b_Success                     INT           OUTPUT  
   , @n_Err                         INT           OUTPUT  
   , @c_ErrMsg                      NVARCHAR(255) OUTPUT  
   , @b_Debug                       INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1

         , @c_WaveType           NVARCHAR(10) = ''
    
         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_Orderlinenumber    NVARCHAR(5)  = ''      
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Lot                NVARCHAR(10) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''  
         , @c_UCCNo              NVARCHAR(20) = ''
         --, @c_Lottable01         NVARCHAR(18) = ''      
         --, @c_Lottable02         NVARCHAR(18) = ''   
         --, @c_Lottable03         NVARCHAR(18) = ''
         --, @dt_Lottable04        DATETIME 
         --, @dt_Lottable05        DATETIME     
  
         --, @c_Lottable06         NVARCHAR(30) = ''
         --, @c_Lottable07         NVARCHAR(30) = ''
         --, @c_Lottable08         NVARCHAR(30) = ''
         --, @c_Lottable09         NVARCHAR(30) = ''
         --, @c_Lottable10         NVARCHAR(30) = ''
         --, @c_Lottable11         NVARCHAR(30) = ''
         --, @c_Lottable12         NVARCHAR(30) = ''
         --, @dt_Lottable13        DATETIME     
         --, @dt_Lottable14        DATETIME
         --, @dt_Lottable15        DATETIME

         , @n_batch              INT = 0
         , @n_RowRef             INT = 0              --(Wan02) 
         , @n_UCC_RowRef         INT = 0
         , @n_QtyAvailable       INT = 0
         , @n_RemainingQty       INT = 0
         , @n_UCCQty             INT = 0
         , @n_QtyLeftToFulfilled INT = 0              --(Wan02) 
         , @n_QtyToTake          INT = 0              --(Wan02)                                                        -- 
         , @c_PickDetailKey      NVARCHAR(10) = ''
         , @c_PickMethod         NVARCHAR(10) = ''

         , @CUR_INV              CURSOR
         , @CUR_ALLOC            CURSOR
         
   DECLARE @tORD                 TABLE 
         ( RowRef                INT IDENTITY(1,1) 
         , Orderkey              NVARCHAR(10) NOT NULL DEFAULT('')
         , OrderLineNumber       NVARCHAR(5)  NOT NULL DEFAULT('')
         , Qty                   INT          NOT NULL DEFAULT(0)
         , AccumulatedQty        INT          NOT NULL DEFAULT(0)
         , QtyAvailable          INT          NOT NULL DEFAULT(0)
         ) 
                 
         
   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_UOM = '7'              --Carton to Piece Pick Loc
   
   IF OBJECT_ID('tempdb..#TMPOD','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMPOD;
   END

   CREATE TABLE #TMPOD
   (  RowRef            INT            IDENTITY(1,1) PRIMARY KEY
   ,  Facility          NVARCHAR(5)    NOT NULL DEFAULT('') 
   ,  Wavekey           NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')  
   ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')  
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')     
   ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('') 
   ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')
   ,  Lottable04        DATETIME       NULL 
   ,  Lottable05        DATETIME       NULL 
   ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')
   ,  Lottable13        DATETIME       NULL     
   ,  Lottable14        DATETIME       NULL 
   ,  Lottable15        DATETIME       NULL 
   ,  Qty               INT            NOT NULL DEFAULT(0)
   ,  SkuLAQty          INT            NOT NULL DEFAULT(0)
   )

   IF OBJECT_ID('tempdb..#TMPALLOC','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMPALLOC;
   END

   CREATE TABLE #TMPALLOC
   (     
      RowRef            INT            IDENTITY(1,1) PRIMARY KEY
   ,  lot               NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  loc               NVARCHAR(10)   NOT NULL DEFAULT('')
--(ML01)   ,  id                NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  id                NVARCHAR(18)   NOT NULL DEFAULT('')       --(ML01)
   ,  qtyavailable      INT            NOT NULL DEFAULT(0)
   ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  OrderLineNumber   NVARCHAR(10)   NOT NULL DEFAULT('')
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')       --(Wan02) 
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')       --(Wan02)  
   )
   
   INSERT INTO #TMPOD
   (        Facility 
         ,  Wavekey  
         ,  Orderkey
         ,  OrderLineNumber 
         ,  Storerkey   
         ,  Sku         
         ,  Lottable01    
         ,  Lottable02  
         ,  Lottable03  
         ,  Lottable04  
         ,  Lottable05  
         ,  Lottable06  
         ,  Lottable07  
         ,  Lottable08  
         ,  Lottable09  
         ,  Lottable10  
         ,  Lottable11  
         ,  Lottable12  
         ,  Lottable13  
         ,  Lottable14  
         ,  Lottable15  
         ,  Qty  
   )  
   SELECT OH.Facility
         ,Wavekey = @c_WaveKey
         ,OD.OrderKey
         ,OD.OrderLineNumber 
         ,OD.Storerkey
         ,OD.Sku
         ,Lottable01 = ISNULL(RTRIM(OD.Lottable01),'')
         ,Lottable02 = ISNULL(RTRIM(OD.Lottable02),'')
         ,Lottable03 = ISNULL(RTRIM(OD.Lottable03),'')
         ,Lottable04 = CASE WHEN OD.Lottable04 IS NOT NULL AND OD.Lottable04 <> '1900-01-01' THEN OD.Lottable04 ELSE '1900-01-01' END
         ,Lottable05 = CASE WHEN OD.Lottable05 IS NOT NULL AND OD.Lottable05 <> '1900-01-01' THEN OD.Lottable05 ELSE '1900-01-01' END
         ,Lottable06 = ISNULL(RTRIM(OD.Lottable06),'')
         ,Lottable07 = ISNULL(RTRIM(OD.Lottable07),'')
         ,Lottable08 = ISNULL(RTRIM(OD.Lottable08),'')
         ,Lottable09 = ISNULL(RTRIM(OD.Lottable09),'')
         ,Lottable10 = ISNULL(RTRIM(OD.Lottable10),'')
         ,Lottable11 = ISNULL(RTRIM(OD.Lottable11),'')
         ,Lottable12 = ISNULL(RTRIM(OD.Lottable12),'')
         ,Lottable13 = CASE WHEN OD.Lottable13 IS NOT NULL AND OD.Lottable13 <> '1900-01-01' THEN OD.Lottable13 ELSE '1900-01-01' END
         ,Lottable14 = CASE WHEN OD.Lottable14 IS NOT NULL AND OD.Lottable14 <> '1900-01-01' THEN OD.Lottable14 ELSE '1900-01-01' END
         ,Lottable15 = CASE WHEN OD.Lottable15 IS NOT NULL AND OD.Lottable15 <> '1900-01-01' THEN OD.Lottable15 ELSE '1900-01-01' END   
         ,OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )
   FROM WAVE        WH WITH (NOLOCK)
   JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey
   JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   WHERE WH.Wavekey = @c_WaveKey
     AND OH.[Type] NOT IN ( 'M', 'I' )   
     AND OH.SOStatus <> 'CANC'   
     AND OH.[Status] < '9'
     AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked ) > 0  
   ORDER BY 
            OD.Storerkey   --(Wan02)
         ,  OD.Sku         --(Wan02)
         ,  OH.Orderkey    --(Wan02) 
 
   IF NOT EXISTS (SELECT 1 FROM #TMPOD)         --(Wan01) 
   BEGIN 
      GOTO QUIT_SP
   END  
   
   ;WITH OD (  Orderkey,   Storerkey, Sku, SkuLAQty
             , Lottable01, Lottable02, Lottable03, Lottable04, Lottable05
             , Lottable06, Lottable07, Lottable08, Lottable09, Lottable10
             , Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
            )
    AS      (  SELECT
               t.Orderkey,   t.Storerkey,  t.Sku, SUM(t.Qty)
             , t.Lottable01, t.Lottable02, t.Lottable03, t.Lottable04, t.Lottable05
             , t.Lottable06, t.Lottable07, t.Lottable08, t.Lottable09, t.Lottable10
             , t.Lottable11, t.Lottable12, t.Lottable13, t.Lottable14, t.Lottable15
               FROM #TMPOD AS t
               GROUP BY t.Orderkey, t.Storerkey, t.Sku
             , t.Lottable01, t.Lottable02, t.Lottable03, t.Lottable04, t.Lottable05
             , t.Lottable06, t.Lottable07, t.Lottable08, t.Lottable09, t.Lottable10
             , t.Lottable11, t.Lottable12, t.Lottable13, t.Lottable14, t.Lottable15
    )
    
    UPDATE t
      SET SkuLAQty = OD.SkuLAQty
    FROM #TMPOD AS t
    JOIN OD ON  OD.Orderkey = t.Orderkey 
            AND OD.Storerkey = t.Storerkey
            AND OD.Sku = t.Sku
            AND OD.Lottable01 = t.Lottable01
            AND OD.Lottable02 = t.Lottable02
            AND OD.Lottable03 = t.Lottable03
            AND OD.Lottable04 = t.Lottable04
            AND OD.Lottable05 = t.Lottable05
            AND OD.Lottable06 = t.Lottable06
            AND OD.Lottable07 = t.Lottable07
            AND OD.Lottable08 = t.Lottable08
            AND OD.Lottable09 = t.Lottable09
            AND OD.Lottable10 = t.Lottable10       
            AND OD.Lottable11 = t.Lottable11
            AND OD.Lottable12 = t.Lottable12
            AND OD.Lottable13 = t.Lottable13
            AND OD.Lottable14 = t.Lottable14
            AND OD.Lottable15 = t.Lottable15
      
   
   IF @b_Debug = 2
   BEGIN
      SELECT * FROM  #TMPOD AS t WITH (NOLOCK)
   END
   
   INSERT INTO #TMPALLOC (lot, loc, id, qtyavailable, Orderkey, OrderLineNumber, Storerkey, Sku)   --(Wan02)
   SELECT lli.Lot, lli.Loc, lli.Id, qtyavailable = (lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen)
      , t.Orderkey, t.OrderLineNumber, lli.Storerkey, lli.Sku                                      --(Wan02)
   FROM #TMPOD t
   JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON t.Storerkey = lli.Storerkey AND t.Sku = lli.Sku 
   JOIN LOT AS l   WITH (NOLOCK)  ON l.Lot = lli.Lot   AND l.[Status]  = 'OK'
   JOIN LOC AS loc WITH (NOLOCK)  ON loc.Loc = lli.Loc AND loc.[Status]= 'OK' AND loc.LocationFlag NOT IN ('HOLD', 'DAMAGE') AND loc.Facility = T.Facility
   JOIN ID  AS id  WITH (NOLOCK)  ON id.id = lli.id   AND id.[Status] = 'OK'
   JOIN LOTATTRIBUTE AS la WITH (NOLOCK) ON  lli.lot = la.lot
   WHERE loc.LocationType IN ('PICK', 'DYNPPICK')
   AND   la.Lottable01 = CASE WHEN t.Lottable01 <> '' THEN t.Lottable01 ELSE la.Lottable01 END 
   AND   la.Lottable02 = CASE WHEN t.Lottable02 <> '' THEN t.Lottable02 ELSE la.Lottable02 END 
   AND   la.Lottable03 = CASE WHEN t.Lottable03 <> '' THEN t.Lottable03 ELSE la.Lottable03 END  
   AND   la.Lottable04 IN ( CASE WHEN t.Lottable04 <> '1900-01-01' THEN t.Lottable04 ELSE la.Lottable04 END ) 
   AND   la.Lottable05 IN ( CASE WHEN t.Lottable05 <> '1900-01-01' THEN t.Lottable05 ELSE la.Lottable05 END )
   AND   la.Lottable06 = CASE WHEN t.Lottable06 <> '' THEN t.Lottable06 ELSE la.Lottable06 END 
   AND   la.Lottable07 = CASE WHEN t.Lottable07 <> '' THEN t.Lottable07 ELSE la.Lottable07 END 
   AND   la.Lottable08 = CASE WHEN t.Lottable08 <> '' THEN t.Lottable08 ELSE la.Lottable08 END 
   AND   la.Lottable09 = CASE WHEN t.Lottable09 <> '' THEN t.Lottable09 ELSE la.Lottable09 END  
   AND   la.Lottable10 = CASE WHEN t.Lottable10 <> '' THEN t.Lottable10 ELSE la.Lottable10 END   
   AND   la.Lottable11 = CASE WHEN t.Lottable11 <> '' THEN t.Lottable11 ELSE la.Lottable11 END 
   AND   la.Lottable12 = CASE WHEN t.Lottable12 <> '' THEN t.Lottable12 ELSE la.Lottable12 END
   AND   la.Lottable13 IN ( CASE WHEN t.Lottable13 <> '1900-01-01' THEN t.Lottable13 ELSE la.Lottable13 END )     
   AND   la.Lottable14 IN ( CASE WHEN t.Lottable14 <> '1900-01-01' THEN t.Lottable14 ELSE la.Lottable14 END )  
   AND   la.Lottable15 IN ( CASE WHEN t.Lottable15 <> '1900-01-01' THEN t.Lottable15 ELSE la.Lottable15 END )
   AND   lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen > 0 
   ORDER BY la.lottable05
         ,  t.Orderkey
         ,  t.OrderLineNumber

   IF @b_Debug = 1
   BEGIN
         SELECT t.Lot
         ,t.Loc
         ,t.ID
         ,qtyavailable = lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen
         ,*
         FROM #TMPALLOC t
         JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
   END
   --(Wan02) - END
   SET @c_Sku = ''
   WHILE 1 = 1
   BEGIN
      SELECT TOP 1   
              @c_Storerkey = t.Storerkey  
            , @c_Sku = t.Sku  
            , @n_QtyLeftToFulfilled = SUM(t.Qty)   
      FROM #TMPOD t  
      WHERE t.Sku > @c_Sku
      AND EXISTS (   SELECT 1 FROM #TMPALLOC AS t2 
                     WHERE t2.Storerkey = t.Storerkey
                     AND t2.Sku = t.Sku
                  )  
      GROUP BY t.Storerkey
            ,  t.Sku
      ORDER BY t.Storerkey
            ,  t.Sku          
      
      IF @@ROWCOUNT = 0
      BEGIN
         BREAK
      END
      
      --(Wan02) - START
      SET @n_RowRef = 0     
      WHILE @n_QtyLeftToFulfilled > 0 AND @n_Continue = 1  
      BEGIN  
         --(Wan02) - START
         --SET @CUR_INV = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
         SELECT TOP 1
                @c_Lot  = t.Lot
               ,@c_Loc  = t.Loc
               ,@c_ID   = t.ID
               ,@n_QtyAvailable = lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen
               ,@n_RowRef = t.RowRef
         FROM #TMPALLOC t
         JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
         WHERE t.RowRef > @n_RowRef
         AND   t.Storerkey = @c_Storerkey
         AND   t.Sku = @c_Sku
         AND   lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen> 0 
         ORDER BY t.RowRef
         --GROUP BY t.Lot
         --      ,  t.Loc
         --      ,  t.ID
         --      ,  lli.Qty
         --      ,  lli.QtyAllocated
         --      ,  lli.QtyPicked
         --      ,  lli.QtyReplen
         --ORDER BY MIN(t.RowRef)
         --(Wan02) - END
         
         IF @@ROWCOUNT = 0 
         BEGIN
            BREAK
         END
         --(Wan02) - START
         --OPEN @CUR_INV
   
         --FETCH NEXT FROM @CUR_INV INTO @c_Lot
         --                           ,  @c_Loc        
         --                           ,  @c_ID              
         --                           ,  @n_QtyAvailable

         --WHILE @@FETCH_STATUS <> -1
         --BEGIN
         --(Wan02) - END
         IF @b_Debug = 1
         BEGIN
             SELECT @n_QtyAvailable '@n_QtyAvailable', 
                     od.OrderKey
                  ,  od.OrderLineNumber
                  ,  od.OpenQty - od.QtyAllocated - od.QtyPicked
                  ,  AccumulatedQty = SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked) OVER (ORDER BY od.OrderKey, od.OrderLineNumber)
                  ,  t.lot, t.loc, t.id
               FROM #TMPALLOC t
               JOIN ORDERDETAIL AS od WITH (NOLOCK) ON (t.Orderkey = od.Orderkey AND t.OrderLineNumber = od.OrderLineNumber)
               WHERE t.lot = @c_Lot
               AND   t.loc = @c_Loc
               AND   t.id  = @c_id                 
               AND   od.OpenQty - od.QtyAllocated - od.QtyPicked > 0
         END

         DELETE FROM @tORD
      
         ;WITH OD ( OrderKey, OrderLineNumber, Qty, AccumulatedQty )
         AS (  SELECT  
                     od.OrderKey
                  ,  od.OrderLineNumber
                  ,  od.OpenQty - od.QtyAllocated - od.QtyPicked
                  ,  AccumulatedQty = SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked) OVER (ORDER BY od.OrderKey, od.OrderLineNumber)
               FROM #TMPALLOC t
               JOIN ORDERDETAIL AS od WITH (NOLOCK) ON (t.Orderkey = od.Orderkey AND t.OrderLineNumber = od.OrderLineNumber)
               WHERE t.lot = @c_Lot
               AND   t.loc = @c_Loc
               AND   t.id  = @c_id                 
               AND   od.OpenQty - od.QtyAllocated - od.QtyPicked > 0
         )
         
         INSERT INTO @tORD (Orderkey, OrderLineNumber, Qty, AccumulatedQty, QtyAvailable)
         SELECT od.OrderKey, od.OrderLineNumber, od.Qty, od.AccumulatedQty
               , QtyAvailable = Lag( @n_QtyAvailable - AccumulatedQty, 1,CASE WHEN Qty >= @n_QtyAvailable THEN @n_QtyAvailable ELSE Qty END) OVER (ORDER BY AccumulatedQty) --Calculate close bal to next row. Default Qty to first Row, put REmaining QtyAvailable (@n_QtyAvailable - AccumulatedQty on row) to next row 
         FROM OD
         ORDER BY AccumulatedQty
  
         IF @b_Debug = 2
         BEGIN
            SELECT * FROM @tORD
         END
      
         IF NOT EXISTS ( SELECT 1 FROM @tORD t
                         WHERE QtyAvailable > 0
                        )
         BEGIN 
            GOTO NEXT_LLI              --(Wan01) 2021--07-19. Continue allocate from Next record
         END
   
         SET @n_batch = 0
         SET @n_QtyToTake = 0                                                                                           --(Wan02)
         SELECT @n_batch = COUNT(1)
               ,@n_QtyToTake = ISNULL(SUM(CASE WHEN t.Qty <= t.QtyAvailable THEN t.Qty ELSE t.QtyAvailable END),0)      --(Wan02)
         FROM @tORD t
         WHERE t.QtyAvailable > 0
         
         EXECUTE nspg_Getkey  
              @KeyName       = 'PickDetailKey'  
            , @fieldlength   = 10  
            , @keystring     = @c_PickDetailKey OUTPUT  
            , @b_Success     = @b_Success       OUTPUT  
            , @n_err         = @n_Err           OUTPUT  
            , @c_errmsg      = @c_ErrMsg        OUTPUT 
            , @b_resultset   = 0 
            , @n_batch       = @n_batch 
                  
         IF @b_Success <> 1  
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 88010
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                           + ': Get PickDetailKey Failed. (ispLuLuLQ7)'
            GOTO QUIT_SP
         END
         
         IF @b_Debug = 1
         BEGIN
            PRINT 'PickCode: ispLuLuLQ7'
               + ',Storerkey: ' + @c_Storerkey
               + ',Sku: ' + @c_Sku
               + ',Lot: ' + @c_Lot
               + ',Loc: ' + @c_Loc
               + ',ID: '  + @c_ID
               + ',UCCNo: '  + @c_UCCNo
               + ',Wavekey: ' + @c_Wavekey
               + ',PickMethod: ' + @c_PickMethod
               + ',UOM: ' + @c_UOM   
               + ',UCCQty: ' + CAST(@n_UCCQty AS NVARCHAR)
               + ',First Pickdetailkey: ' + @c_PickDetailKey
               + ',Gen Pickdetailkey Batch: ' + CAST(@n_batch AS NVARCHAR)   
         END
      
         IF @b_Debug = 2   
         BEGIN     
            SELECT pickcode = 'ispLuLuLQ7' 
               --,  Pickdetailkey = RIGHT( '0000000000' +  CAST( CAST(@c_PickDetailKey AS INT) + ROW_NUMBER() OVER (ORDER BY od.OrderKey, od.OrderLineNumber) AS NVARCHAR) - 1 , 10)
               ,  Pickdetailkey = RIGHT( '0000000000' +  CAST( CAST(@c_PickDetailKey AS INT) + ROW_NUMBER() OVER (ORDER BY od.OrderKey, od.OrderLineNumber) -1 AS NVARCHAR), 10)
               ,  CaseID = ''
               ,  PickHeaderKey = ''
               ,  od.OrderKey
               ,  od.OrderLineNumber
               ,  od.Storerkey
               ,  od.Sku
               ,  Lot = @c_Lot
               ,  Loc = @c_Loc
               ,  ID  = @c_ID
               ,  UCCNo = @c_UCCNo
               ,  s.PackKey
               ,  UOM = @c_UOM
               ,  Qty    = CASE WHEN t.Qty <= t.QtyAvailable THEN t.Qty ELSE t.QtyAvailable END
               ,  UOMQty = CASE WHEN t.Qty <= t.QtyAvailable THEN t.Qty ELSE t.QtyAvailable END
               ,  CartonGroup  = ''
               ,  DoReplenish  = 'N'
               ,  PickMethod   = p.PACKUOM3
               ,  Wavekey      = @c_WaveKey
               ,  Replenishzone= ''
               ,  doCartonize  = NULL
               ,  Trafficcop   = 'U'
            FROM @tORD t
            JOIN ORDERDETAIL AS od WITH (NOLOCK) ON t.Orderkey = od.OrderKey AND t.OrderLineNumber = od.OrderLineNumber
            JOIN SKU AS s WITH (NOLOCK) ON s.StorerKey = od.StorerKey AND s.Sku = od.Sku
            JOIN PACK AS p WITH (NOLOCK) ON p.Packkey  = s.Packkey
            WHERE t.QtyAvailable > 0  
 
         END
         
         -- INSERT PICKDETAIL BY BATCH
         INSERT INTO PICKDETAIL 
            (  PickDetailKey
            ,  CaseID
            ,  PickHeaderKey
            ,  OrderKey
            ,  OrderLineNumber
            ,  Storerkey
            ,  Sku
            ,  Lot
            ,  Loc
            ,  ID
            ,  DropID
            ,  PackKey
            ,  UOM 
            ,  Qty
            ,  UOMQty
            ,  CartonGroup
            ,  DoReplenish
            ,  PickMethod
            ,  WaveKey
            ,  Replenishzone
            ,  doCartonize
            ,  Trafficcop
            )
         SELECT 
               Pickdetailkey = RIGHT( '0000000000' +  CAST( CAST(@c_PickDetailKey AS INT) + ROW_NUMBER() OVER (ORDER BY od.OrderKey, od.OrderLineNumber) -1 AS NVARCHAR), 10)
            ,  CaseID = ''
            ,  PickHeaderKey = ''
            ,  od.OrderKey
            ,  od.OrderLineNumber
            ,  od.Storerkey
            ,  od.Sku
            ,  Lot = @c_Lot
            ,  Loc = @c_Loc
            ,  ID  = @c_ID
            ,  UCCNo = @c_UCCNo
            ,  s.PackKey
            ,  UOM = @c_UOM
            ,  Qty    = CASE WHEN t.Qty <= QtyAvailable THEN t.Qty ELSE t.QtyAvailable END
            ,  UOMQty = CASE WHEN t.Qty <= QtyAvailable THEN t.Qty ELSE t.QtyAvailable END
            ,  CartonGroup  = ''
            ,  DoReplenish  = 'N'
            ,  PickMethod   = p.PACKUOM3
            ,  Wavekey      = @c_WaveKey
            ,  Replenishzone= ''
            ,  doCartonize  = NULL
            ,  Trafficcop   = 'U'
         FROM @tORD t
         JOIN ORDERDETAIL AS od WITH (NOLOCK) ON t.Orderkey = od.OrderKey AND t.OrderLineNumber = od.OrderLineNumber
         JOIN SKU AS s WITH (NOLOCK) ON s.StorerKey = od.StorerKey AND s.Sku = od.Sku
         JOIN PACK AS p WITH (NOLOCK) ON p.Packkey  = s.Packkey
         WHERE t.QtyAvailable > 0  

         SET @n_Err = @@ERROR
         
         IF @n_Err <> 0 
         BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 88020
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert Into Pickdetail table Fail. (ispLuLuLQ7)'
            GOTO QUIT_SP
         END
         
         SET @n_QtyLeftToFulfilled = @n_QtyLeftToFulfilled - @n_QtyToTake        --(Wan02)
         NEXT_LLI:
         --(Wan02) - START
         --FETCH NEXT FROM @CUR_INV INTO @c_Lot
         --                           ,  @c_Loc        
         --                           ,  @c_ID              
         --                           ,  @n_QtyAvailable  
         --(Wan02) - END  
      END   --@n_QtyLeftToFulfilled > 0 
      --CLOSE @CUR_INV
      --DEALLOCATE @CUR_INV  
   END      --@c_SKU    
   --(Wan03) - END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispLuLuLQ7'
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