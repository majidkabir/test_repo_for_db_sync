SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispLuLuMFC2                                             */
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
/* 2023-09-07  Michael  1.2   Extend #TMPALLOC.ID len to 18 (ML01)      */
/* 2023-10-13  Michael  1.3   WMS-23889 move hardcoded DC Code to       */
/*                            CodeLkup LULUDCCODE with UDF01=4PL (ML02) */
/************************************************************************/
CREATE PROC [dbo].[ispLuLuMFC2]
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

         , @n_batch              INT = 0
         , @b_aUCC               INT = 0              --(Wan01)
         , @n_RowRef             INT = 0              --(Wan01)
         , @n_UCC_RowRef         INT = 0
         , @n_QtyAvailable       INT = 0
         , @n_RemainingQty       INT = 0
         , @n_UCCQty             INT = 0
         , @c_PickDetailKey      NVARCHAR(10) = ''
         , @c_PickMethod         NVARCHAR(10) = 'C'

         , @CUR_INV              CURSOR
         , @CUR_ALLOC            CURSOR

   DECLARE @tORD                 TABLE 
         ( RowRef                INT IDENTITY(1,1) 
         , Orderkey              NVARCHAR(10) NOT NULL DEFAULT('')
         , OrderLineNumber       NVARCHAR(5)  NOT NULL DEFAULT('')
         , Qty                   INT          NOT NULL DEFAULT(0)
         , AccumulatedQty        INT          NOT NULL DEFAULT(0) 
         , UCCQty                INT          NOT NULL DEFAULT(0) 
         )  
         
   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''
   
   SET @c_UOM = '2'
   
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

   IF OBJECT_ID('tempdb..#TMPUCC','u') IS NOT NULL
   BEGIN
      DROP TABLE #TMPUCC;
   END

   CREATE TABLE #TMPUCC
   (  RowRef            INT            IDENTITY(1,1) PRIMARY KEY        --(Wan01)
   ,  UCC_RowRef        BIGINT         NOT NULL DEFAULT('')             --(Wan01)
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')
   ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT('')     
   ,  Loc               NVARCHAR(10)   NOT NULL DEFAULT('') 
   ,  ID                NVARCHAR(18)   NOT NULL DEFAULT('')
   ,  Qty               INT            NOT NULL DEFAULT(0)
   ,  Orderkey          NVARCHAR(10)   NOT NULL DEFAULT('')  
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
   ,  OrderLineNumber   NVARCHAR(5)    NOT NULL DEFAULT('')
   ,  SkuLAQty          INT            NOT NULL DEFAULT(0)
   ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')
   ,  UCCNo             NVARCHAR(20)   NOT NULL DEFAULT('')
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
     AND OH.[Type] NOT IN ( 'M', 'I', 'LULUECOM' )   
     AND OH.SOStatus <> 'CANC'   
     AND OH.[Status] < '9'
--(ML02)     AND OH.UserDefine10 IN ('170146','170149')  --Mexico Order
     AND EXISTS(SELECT TOP 1 1 FROM CODELKUP CL(NOLOCK) WHERE CL.LISTNAME='LULUDCCODE' AND CL.UDF01='4PL' AND CL.Storerkey=OH.Storerkey AND CL.Code=OH.UserDefine10)   --(ML02)
     AND OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked ) > 0 
     
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
      
   SELECT TOP 1 @c_Storerkey = t.Storerkey
   FROM #TMPOD t   
   
   IF @b_Debug = 2
   BEGIN 
      SELECT UCC_RowRef = u.UCC_RowRef, u.UCCNo, u.Storerkey, u.Sku, u.Lot, u.Loc, u.ID, u.Qty, mu.Orderkey 
      FROM (
         SELECT u.UCCNo, u.Storerkey, t.Orderkey
         FROM UCC AS u WITH (NOLOCK) 
         LEFT OUTER JOIN #TMPOD t ON u.Storerkey = t.Storerkey AND u.SKU = t.Sku 
         WHERE u.Storerkey = @c_Storerkey
         GROUP BY u.Storerkey
               ,  u.UCCNo
               ,  t.Orderkey
         HAVING COUNT(DISTINCT u.SKU) > 1 
         AND COUNT(DISTINCT u.[Status]) = 1 AND MAX(u.[Status]) = '1'
         AND MIN(CASE WHEN u.Qty <= t.SkuLAQty THEN 1 ELSE 0 END) = 1    
         AND MIN(CASE WHEN u.SKU = t.Sku THEN 1 ELSE 0 END) = 1
         ) mu
      JOIN UCC AS u WITH (NOLOCK) ON  u.Storerkey = mu.Storerkey AND u.UCCNo = mu.UCCNo 
   END
   
   ;WITH MIXUCC (UCCNo, Storerkey, Orderkey)
   AS (  SELECT u.UCCNo, u.Storerkey, t.Orderkey
         FROM UCC AS u WITH (NOLOCK) 
         LEFT OUTER JOIN #TMPOD t ON u.Storerkey = t.Storerkey AND u.SKU = t.Sku 
         WHERE u.Storerkey = @c_Storerkey
         GROUP BY u.Storerkey
               ,  u.UCCNo
               ,  t.Orderkey
         HAVING COUNT(DISTINCT u.SKU) > 1 
         AND COUNT(DISTINCT u.[Status]) = 1 AND MAX(u.[Status]) = '1'
         AND MIN(CASE WHEN u.Qty <= t.SkuLAQty THEN 1 ELSE 0 END) = 1    
         AND MIN(CASE WHEN u.SKU = t.Sku THEN 1 ELSE 0 END) = 1
   )
   
   INSERT INTO #TMPUCC (UCC_RowRef, UCCNo, Storerkey, Sku, Lot, Loc, ID, Qty, Orderkey)
   SELECT UCC_RowRef = u.UCC_RowRef, u.UCCNo, u.Storerkey, u.Sku, u.Lot, u.Loc, u.ID, u.Qty, mu.Orderkey
   FROM MIXUCC mu 
   JOIN UCC AS u WITH (NOLOCK) ON  u.Storerkey = mu.Storerkey AND u.UCCNo = mu.UCCNo 

   IF @b_Debug = 2
   BEGIN 
       SELECT * FROM #TMPUCC AS t
       ORDER BY t.UCCno
   END
   
   INSERT INTO #TMPALLOC (lot, loc, id, qtyavailable, Orderkey, OrderLineNumber, SKULAQty, Storerkey, UCCNo)
   SELECT lli.Lot, lli.Loc, lli.Id, qtyavailable = (lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen)
         ,t.Orderkey, t.OrderLineNumber, t.SkuLAQty, ucc.Storerkey, ucc.UCCNo
   FROM #TMPOD t
   JOIN #TMPUCC AS ucc WITH (NOLOCK) ON  t.Storerkey = ucc.Storerkey
                                     AND t.Sku       = ucc.sku
                                     AND t.Orderkey  = ucc.Orderkey
   JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON ucc.Lot = lli.Lot AND ucc.Loc = lli.loc AND ucc.id = lli.id
   JOIN LOT AS l   WITH (NOLOCK)  ON l.Lot = lli.Lot   AND l.[Status]  = 'OK'
   JOIN LOC AS loc WITH (NOLOCK)  ON loc.Loc = lli.Loc AND loc.[Status]= 'OK' AND loc.LocationFlag NOT IN ('HOLD', 'DAMAGE') AND loc.Facility = T.Facility
   JOIN ID  AS id  WITH (NOLOCK)  ON id.id = lli.id   AND id.[Status] = 'OK'
   JOIN LOTATTRIBUTE AS la WITH (NOLOCK) ON  lli.lot = la.lot
   WHERE loc.LocationType NOT IN ('PICK', 'DYNPPICK')
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
   GROUP BY lli.Lot
         ,  lli.Loc
         ,  lli.Id
         ,  lli.Qty
         ,  lli.QtyAllocated
         ,  lli.QtyPicked
         ,  lli.QtyReplen
         ,  t.Orderkey
         ,  t.OrderLineNumber
         ,  t.SkuLAQty
         ,  ucc.Storerkey
         ,  ucc.UCCNo    
   ORDER BY MIN(la.lottable05)
         , ucc.UCCNo
         , t.Orderkey
         , t.OrderLineNumber

   IF @b_Debug = 2
   BEGIN
      SELECT * FROM #TMPALLOC t
      
      SELECT u.UCCNo , [Match] = CASE WHEN ISNULL(SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked ),0) - u.qty  >= 0 THEN 1 ELSE 0 END
           , tu.Orderkey
         FROM #TMPALLOC t
         JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
         JOIN #TMPUCC tu ON t.Storerkey = tu.Storerkey AND t.UCCNo = tu.UCCNo 
                           AND lli.Lot = tu.Lot AND lli.loc = tu.loc AND lli.id = tu.id
                           AND t.Orderkey = tu.Orderkey
         JOIN UCC AS u WITH (NOLOCK) ON u.UCC_RowRef = tu.UCC_RowRef
         LEFT JOIN ORDERDETAIL AS od WITH (NOLOCK) ON (t.Orderkey = od.Orderkey AND t.OrderLineNumber = od.OrderLineNumber)
         WHERE tu.UCCNo > @c_UCCNo
         AND u.Qty <= lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen
         GROUP BY u.UCCNo
               ,  u.Qty
               ,  tu.Orderkey
               ,  lli.Lot
               ,  lli.Loc
               ,  lli.ID
               ,  lli.Qty 
               ,  lli.QtyAllocated 
               ,  lli.QtyPicked 
               ,  lli.QtyReplen
 
   END
   
   SET @c_UCCNo = ''
   SET @n_RowRef= 0     --(Wan01) 
   WHILE 1=1
   BEGIN
      --(Wan01) - START
      /*
      ;WITH t2 ( UCCNo, [Match], Orderkey, RowRef ) AS
      (  SELECT u.UCCNo , [Match] = CASE WHEN ISNULL(SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked ),0) - u.qty  >= 0 THEN 1 ELSE 0 END
               ,tu.Orderkey
               ,RowRef = ROW_NUMBER() OVER (ORDER BY MIN(t.RowRef))
         FROM #TMPALLOC t
         JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
         JOIN #TMPUCC tu ON t.Storerkey = tu.Storerkey AND t.UCCNo = tu.UCCNo 
                           AND lli.Lot = tu.Lot AND lli.loc = tu.loc AND lli.id = tu.id
         JOIN UCC AS u WITH (NOLOCK) ON u.UCC_RowRef = tu.UCC_RowRef
         LEFT JOIN ORDERDETAIL AS od WITH (NOLOCK) ON (t.Orderkey = od.Orderkey AND t.OrderLineNumber = od.OrderLineNumber)
         WHERE u.Qty <= lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen        --(Wan01)
         GROUP BY u.UCCNo
               ,  u.Qty
               ,  tu.Orderkey
               ,  lli.Lot
               ,  lli.Loc
               ,  lli.ID
               ,  lli.Qty 
               ,  lli.QtyAllocated 
               ,  lli.QtyPicked 
               ,  lli.QtyReplen
         HAVING u.Qty > 0 
         AND MAX(u.[Status]) = '1'
      )
                 
      SELECT TOP 1 
            @c_UCCNo = t2.UCCNo
         ,  @c_Orderkey = t2.Orderkey
      FROM t2
      --WHERE t2.UCCNo > @c_UCCNo
      GROUP BY t2.uccno
            ,  t2.Orderkey
      HAVING MIN(t2.[Match]) = 1  
      ORDER BY MIN(t2.RowRef)
      */

      IF @b_Debug = 2 
      BEGIN
         SELECT t.UCCNo
               ,t.Orderkey, t2.UCCNo, t2.Storerkey, t2.Sku ,us.UCCNo, us.Storerkey, us.Sku
         FROM #TMPALLOC AS t 
         JOIN #TMPUCC AS t2 ON t2.UCCNo = t.UCCNo AND t2.Orderkey = t.Orderkey
         LEFT OUTER JOIN
         (
            SELECT
                     u.UCCNo 
                  ,  tu.Orderkey
                  ,  u.Storerkey
                  ,  u.Sku
            FROM #TMPALLOC t
            JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
            JOIN #TMPUCC tu ON t.Storerkey = tu.Storerkey AND t.UCCNo = tu.UCCNo 
                            AND lli.Lot = tu.Lot AND lli.loc = tu.loc AND lli.id = tu.id
                            AND t.Orderkey = tu.Orderkey
            JOIN UCC AS u WITH (NOLOCK) ON u.UCC_RowRef = tu.UCC_RowRef
            --WHERE t.RowRef > @n_RowRef
            WHERE u.Qty > 0 
            AND   u.[Status] = '1'
            AND   u.Qty <= lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen
            GROUP BY u.UCCNo
                  ,  u.Storerkey
                  ,  u.Sku
                  ,  tu.Orderkey
            HAVING SUM(u.Qty) > 0
            AND SUM(u.Qty) <= SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen) 
            AND NOT EXISTS (  SELECT 1
                              FROM ORDERDETAIL AS od WITH   (NOLOCK) 
                              WHERE od.Orderkey = tu.Orderkey 
                              AND   od.Storerkey= u.Storerkey
                              AND   od.Sku = u.Sku
                              GROUP BY od.Orderkey
                                      ,od.Storerkey
                                      ,od.Sku
                              HAVING SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked) - SUM(u.Qty) < 0
                            ) 
         ) AS us ON us.UCCNo = t2.UCCNo AND us.Storerkey = t2.Storerkey AND us.Sku = t2.Sku AND us.Orderkey = t2.Orderkey 
         --GROUP BY t.UCCNo, t.Orderkey
         --HAVING SUM(CASE WHEN us.UCCNo IS NULL THEN 1 ELSE 0 END) = 0
         --ORDER BY MAX(t.RowRef)
         
         ORDER BY t.UCCNo, t.Orderkey
      END

      ;WITH us ( UCCNo, Orderkey, Storerkey, Sku  ) AS
      (  SELECT
               u.UCCNo 
            ,  tu.Orderkey
            ,  u.Storerkey
            ,  u.Sku
         FROM #TMPALLOC t
         JOIN LOTxLOCxID AS lli WITH (NOLOCK) ON lli.Lot = t.Lot AND lli.loc = t.loc AND lli.id = t.id
         JOIN #TMPUCC tu ON t.Storerkey = tu.Storerkey AND t.UCCNo = tu.UCCNo 
                           AND lli.Lot = tu.Lot AND lli.loc = tu.loc AND lli.id = tu.id
                           AND t.Orderkey = tu.Orderkey
         JOIN UCC AS u WITH (NOLOCK) ON u.UCC_RowRef = tu.UCC_RowRef
         --WHERE t.RowRef > @n_RowRef
         WHERE u.Qty > 0 
         AND   u.[Status] = '1'
         AND   u.Qty <= lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen 
         GROUP BY u.UCCNo
               ,  u.Storerkey
               ,  u.Sku
               ,  tu.Orderkey
         HAVING SUM(u.Qty) > 0
         AND SUM(u.Qty) <= SUM(lli.Qty - lli.QtyAllocated - lli.QtyPicked - lli.QtyReplen) 
         AND NOT EXISTS (  SELECT 1
                           FROM ORDERDETAIL AS od WITH   (NOLOCK) 
                           WHERE od.Orderkey = tu.Orderkey 
                           AND   od.Storerkey= u.Storerkey
                           AND   od.Sku = u.Sku
                           GROUP BY od.Orderkey
                                    ,od.Storerkey
                                    ,od.Sku
                           HAVING SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked) - SUM(u.Qty) < 0
                           ) 
         
      )
      SELECT TOP 1
             @c_UCCNo = t.UCCNo
            ,@c_Orderkey = t.Orderkey
            ,@n_RowRef   = MAX(t.RowRef)
      FROM #TMPALLOC AS t 
      JOIN #TMPUCC AS t2 ON t2.UCCNo = t.UCCNo AND t2.Orderkey = t.Orderkey
      LEFT OUTER JOIN us ON us.UCCNo = t2.UCCNo AND us.Storerkey = t2.Storerkey AND us.Sku = t2.Sku AND us.Orderkey = t2.Orderkey
      WHERE t.RowRef > @n_RowRef 
      GROUP BY t.UCCNo
              ,t.Orderkey
      HAVING SUM(CASE WHEN us.UCCNo IS NULL THEN 1 ELSE 0 END) = 0
      ORDER BY MAX(t.RowRef)
      --(Wan01) - END 
      
      IF @@ROWCOUNT = 0                      --(Wan01)
      BEGIN
         BREAK
      END

      IF @b_Debug = 2
      BEGIN
         PRINT 'GET UCCNo: ' + @c_UCCNo
              +',@c_ORderkey: ' + @c_ORderkey
         SELECT u.UCC_RowRef
               ,u.UCCNo
               ,u.Qty
               ,u.Lot
               ,u.Loc
               ,u.ID
         FROM #TMPUCC t
         JOIN UCC u WITH (NOLOCK) ON t.UCC_RowRef = u.UCC_RowRef
         WHERE t.UCCNo = @c_UCCNo
         AND t.Orderkey= @c_Orderkey
         ORDER BY u.UCC_RowRef
      END
      
      SET @b_aUCC = 0
      -- Get UCCNo Inventory to allocate orderkey
      SET @CUR_ALLOC = CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT u.UCC_RowRef
            ,u.Qty
            ,u.Lot
            ,u.Loc
            ,u.ID
      FROM #TMPUCC t
      JOIN UCC u WITH (NOLOCK) ON t.UCC_RowRef = u.UCC_RowRef
      WHERE t.UCCNo = @c_UCCNo
      AND t.Orderkey= @c_Orderkey
      ORDER BY u.UCC_RowRef

      OPEN @CUR_ALLOC
   
      FETCH NEXT FROM @CUR_ALLOC INTO  @n_UCC_RowRef
                                    ,  @n_UCCQty  
                                    ,  @c_Lot
                                    ,  @c_Loc        
                                    ,  @c_ID              
                                          
      WHILE @@FETCH_STATUS <> -1 
      BEGIN
         IF @b_Debug = 1
         BEGIN
            PRINT '@c_ORderkey: ' + @c_ORderkey
             + ',@c_UCCNo:    : ' + @c_UCCNo
             + ',@n_UCC_RowRef: ' +  CAST ( @n_UCC_RowRef AS NVARCHAR)
             + ',@n_UCCQty    : ' +  CAST ( @n_UCCQty AS NVARCHAR)
             + ',@c_Lot       : ' + @c_Lot
             + ',@c_Loc       : ' + @c_Loc
             + ',@c_ID        : ' + @c_ID 
         END 
         
         DELETE FROM @tORD
         
         ;WITH OD ( OrderKey, OrderLineNumber, Qty, AccumulatedQty )
         AS (  SELECT  
                     od.OrderKey
                  ,  od.OrderLineNumber
                  ,  od.OpenQty - od.QtyAllocated - od.QtyPicked
                  ,  AccumulatedQty = SUM(od.OpenQty - od.QtyAllocated - od.QtyPicked) OVER (PARTITION BY od.OrderKey ORDER BY od.OrderKey, od.OrderLineNumber)
               FROM #TMPALLOC t
               JOIN ORDERDETAIL AS od WITH (NOLOCK) ON (t.Orderkey = od.Orderkey AND t.OrderLineNumber = od.OrderLineNumber)
               WHERE t.Orderkey = @c_Orderkey
               AND   t.lot = @c_Lot
               AND   t.loc = @c_Loc
               AND   t.id  = @c_id   
               AND   t.UCCNo = @c_UCCNo              
               --AND   od.OpenQty - od.QtyAllocated - od.QtyPicked >= @n_UCCQty
               AND   od.OpenQty - od.QtyAllocated - od.QtyPicked > 0
         )
         
         INSERT INTO @tORD (Orderkey, OrderLineNumber, Qty, AccumulatedQty, UCCQty)
         SELECT od.OrderKey, od.OrderLineNumber, od.Qty, od.AccumulatedQty
               , QtyAvailable = Lag( @n_UCCQty - AccumulatedQty, 1, CASE WHEN Qty <= @n_UCCQty THEN Qty ELSE @n_UCCQty END ) 
                                OVER (ORDER BY AccumulatedQty) -- Default Qty to first Row, put Remaining UCCQty (@n_UCCQty - AccumulatedQty on row) to next row 
         FROM OD
         ORDER BY AccumulatedQty


         IF @b_Debug = 2
         BEGIN
            SELECT @n_UCCQty, * FROM @tORD
         END   
                  
         IF NOT EXISTS ( SELECT 1 FROM @tORD t
                         WHERE UCCQty > 0
                       )
         BEGIN 
            GOTO NEXT_UCC_LLI       --(Wan01) 2021-07-19. Continue allocate from Next record
         END
         
         SELECT TOP 1 @n_RemainingQty = t.AccumulatedQty
         FROM @tORD t
         ORDER BY AccumulatedQty DESC
         
         IF @n_RemainingQty = 0 
         BEGIN 
            GOTO NEXT_UCC_LLI       --(Wan01) 2021-07-19. Continue allocate from Next record
         END
         
         -- IF UCC Qty > Total to allocate Qty in the Wave (Cannot use up 1 UCC for wave's order lines allocation)    
         IF @n_UCCQty > @n_RemainingQty 
         BEGIN
            GOTO NEXT_UCC_LLI       --(Wan01) 2021-07-19. Continue allocate from Next record
         END 

         SET @n_batch = 0
         SELECT @n_batch = COUNT(1)
         FROM @tORD t
         WHERE t.UCCQty > 0
         AND t.AccumulatedQty > 0
         
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
                           + ': Get PickDetailKey Failed. (ispLuLuMFC2)'
            GOTO QUIT_SP
         END
         
         IF @b_Debug = 1
         BEGIN
            PRINT 'PickCode: ispLuLuMFC2'
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
            SELECT  'ispLuLuMFC2' AS 'PickCode' , @c_UCCNo 'UCCNo', @c_Lot 'Lot', @c_Loc 'Loc', @c_id 'ID', s.Packkey, t.*
            FROM @tORD t
            JOIN ORDERDETAIL AS od WITH (NOLOCK) ON t.Orderkey = od.OrderKey AND t.OrderLineNumber = od.OrderLineNumber
            JOIN SKU AS s WITH (NOLOCK) ON s.StorerKey = od.StorerKey AND s.Sku = od.Sku 
            
            SELECT PickCode = 'ispLuLuMFC2'
               ,   Pickdetailkey = RIGHT( '0000000000' +  CAST( CAST(@c_PickDetailKey AS INT) + ROW_NUMBER() OVER (ORDER BY od.OrderKey, od.OrderLineNumber) - 1 AS NVARCHAR) , 10)
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
               ,  Qty = CASE WHEN t.Qty <= t.UCCQty THEN t.Qty ELSE t.UCCQty END
               ,  UCCQty = @n_UCCQty
               ,  CartonGroup  = ''
               ,  DoReplenish  = 'N'
               ,  PickMethod   = @c_PickMethod
               ,  Wavekey      = @c_WaveKey           
               ,  Replenishzone= ''
               ,  doCartonize  = NULL
               ,  Trafficcop   = 'U'
            FROM @tORD t
            JOIN ORDERDETAIL AS od WITH (NOLOCK) ON t.Orderkey = od.OrderKey AND t.OrderLineNumber = od.OrderLineNumber
            JOIN SKU AS s WITH (NOLOCK) ON s.StorerKey = od.StorerKey AND s.Sku = od.Sku
            WHERE t.UCCQty > 0
            AND t.AccumulatedQty > 0
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
            ,  DropID = @c_UCCNo
            ,  s.PackKey
            ,  UOM = @c_UOM
            ,  Qty = CASE WHEN t.Qty <= t.UCCQty THEN t.Qty ELSE t.UCCQty END
            ,  UCCQty = @n_UCCQty
            ,  CartonGroup  = ''
            ,  DoReplenish  = 'N'
            ,  PickMethod   = @c_PickMethod
            ,  Wavekey      = @c_WaveKey           
            ,  Replenishzone= ''
            ,  doCartonize  = NULL
            ,  Trafficcop   = 'U'
         FROM @tORD t
         JOIN ORDERDETAIL AS od WITH (NOLOCK) ON t.Orderkey = od.OrderKey AND t.OrderLineNumber = od.OrderLineNumber
         JOIN SKU AS s WITH (NOLOCK) ON s.StorerKey = od.StorerKey AND s.Sku = od.Sku
         WHERE t.UCCQty > 0
         AND t.AccumulatedQty > 0
                     
         SET @n_Err = @@ERROR
         
         IF @n_Err <> 0 
         BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 88020
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert Into Pickdetail table Fail. (ispLuLuMFC2)'
            GOTO QUIT_SP
         END

         SET @b_aUCC = 1
         UPDATE UCC
         SET [Status] = '3'
            , EditDate= GETDATE()
            , EditWho = SUSER_SNAME()
            , TrafficCop = NULL
         WHERE UCC_RowRef = @n_UCC_RowRef
         
         SET @n_Err = @@ERROR
         
         IF @n_Err <> 0 
         BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 88030
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Update UCC table Fail.  (ispLuLuMFC2)'
            GOTO QUIT_SP
         END         
         
         IF @b_Debug = 2
         BEGIN
            SELECT [Status]
            FROM UCC WITH (NOLOCK)
            WHERE UCC_RowRef = @n_UCC_RowRef
         END
          
         NEXT_UCC_LLI:
         FETCH NEXT FROM @CUR_ALLOC INTO  @n_UCC_RowRef
                                       ,  @n_UCCQty  
                                       ,  @c_Lot
                                       ,  @c_Loc        
                                       ,  @c_ID              
      END
      CLOSE @CUR_ALLOC
      DEALLOCATE @CUR_ALLOC

      IF @b_aUCC = 1 
      BEGIN
         IF EXISTS (SELECT 1
                    FROM UCC AS u WITH (NOLOCK)
                    WHERE u.Storerkey = @c_Storerkey
                    AND u.UCCNo = @c_UCCNo
                    GROUP BY u.UCCNo
                    HAVING COUNT(DISTINCT u.[Status]) > 1
         )
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 88040
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Mix Sku UCCNo does not Fully Allocate.  (ispLuLuMFC2)'
            GOTO QUIT_SP
         END
       END
   END

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispLuLuMFC2'
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