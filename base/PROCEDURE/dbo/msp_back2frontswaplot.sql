SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* S Proc: msp_Back2FrontSwapLot                                        */
/* Creation Date: 2023-11-23                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To solve the integrity for qty expected between the         */
/*          LOTxLOCxID and SKUxLOC                                      */
/*        : FCR-1430 - Gap on Swap lot when move                        */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* OUTPUT Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: Trigger when inventory move                                   */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: msp_ReplBack2Front                                        */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/************************************************************************/
CREATE   PROC [dbo].[msp_Back2FrontSwapLot]
   @c_LOT            NVARCHAR(10) 
,  @c_LOC            NVARCHAR(10) 
,  @c_ID             NVARCHAR(18)    
,  @b_Success        INT = 1              OUTPUT 
,  @n_ErrNo          INT = 0              OUTPUT    
,  @c_ErrMsg         NVARCHAR(250) = ''   OUTPUT   
,  @b_Debug          INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1  
      ,  @c_Orderkey             NVARCHAR(10)   = ''
      ,  @c_Loadkey              NVARCHAR(10)   = ''
      ,  @c_PickDetailKey        NVARCHAR(10)   = ''
      ,  @n_Rows                 INT            = 0
      ,  @n_RowCount             INT            = 0
      ,  @c_StorerKey            NVARCHAR(15)   = ''
      ,  @c_Ctrl                 NVARCHAR(1)    = ''
      ,  @c_SKU                  NVARCHAR(20)   = ''
      ,  @n_Qty                  INT            = 0
      ,  @c_ReplenLOT            NVARCHAR(10)   = ''
      ,  @c_ReplenID             NVARCHAR(18)   = ''
      ,  @n_LotQty               INT            = 0
      ,  @c_NewPickDetailKey     NVARCHAR(18)   = ''
      ,  @c_Status               NVARCHAR(5)    = ''
      ,  @c_ShipFlag             NVARCHAR(1)    = ''
      ,  @n_LOTQty2              INT            = 0
      ,  @c_ForceAllocLottable   NVARCHAR(1)    =''

      ,  @c_Lottable01           NVARCHAR(18)   = ''  
      ,  @c_Lottable02           NVARCHAR(18)   = '' 
      ,  @c_Lottable03           NVARCHAR(18)   = '' 
      ,  @d_Lottable04           DATETIME           
      ,  @c_Lottable06           NVARCHAR(30)   = ''  
      ,  @c_Lottable07           NVARCHAR(30)   = ''  
      ,  @c_Lottable08           NVARCHAR(30)   = ''  
      ,  @c_Lottable09           NVARCHAR(30)   = ''  
      ,  @c_Lottable10           NVARCHAR(30)   = ''  
      ,  @c_Lottable11           NVARCHAR(30)   = ''  
      ,  @c_Lottable12           NVARCHAR(30)   = ''  
      ,  @c_forcelottablelist    NVARCHAR(500)  = ''  
      ,  @n_ReplenQty            INT            = 0 
      ,  @n_Priority             INT            = 9 
      ,  @n_FetchStatus          INT            = 0 
      ,  @c_ODLottable01         NVARCHAR(18)   = ''    
      ,  @c_ODLottable02         NVARCHAR(18)   = '' 
      ,  @c_ODLottable03         NVARCHAR(18)   = '' 
      ,  @c_ODLottable06         NVARCHAR(30)   = ''  
      ,  @c_ODLottable07         NVARCHAR(30)   = ''  
      ,  @c_ODLottable08         NVARCHAR(30)   = ''  
      ,  @c_ODLottable09         NVARCHAR(30)   = ''  
      ,  @c_ODLottable10         NVARCHAR(30)   = ''  
      ,  @c_ODLottable11         NVARCHAR(30)   = ''  
      ,  @c_ODLottable12         NVARCHAR(30)   = ''
      ,  @c_SQLSelect            NVARCHAR(4000) = '' 
      
      ,  @n_Qty_OpenAvail        INT            = 0
      ,  @n_QtyAvail             INT            = 0   
      ,  @c_ID_PD                NVARCHAR(18)   = ''

   SET @n_Rows = 0
   SET @c_Ctrl = '0'

   IF OBJECT_ID('#LotXLocXID') IS NOT NULL
   BEGIN 
      DROP TABLE #LotXLocXID
   END

   CREATE TABLE #LotXLocXID
      (  RowId       INT            IDENTITY(1,1)  PRIMARY Key
      ,  Lot         NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  Loc         NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ID          NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  QtyAvail    INT            NOT NULL DEFAULT(0)
      )

   SET @n_LotQty = 0
   SELECT @c_StorerKey  = LLI.StorerKey, 
          @c_SKU        = LLI.Sku,
          @c_Lottable01 = LA.Lottable01, 
          @c_Lottable02 = LA.Lottable02, 
          @c_Lottable03 = LA.Lottable03, 
          @d_Lottable04 = LA.Lottable04,
          @c_Lottable06 = LA.Lottable06, 
          @c_Lottable07 = LA.Lottable07, 
          @c_Lottable08 = LA.Lottable08, 
          @c_Lottable09 = LA.Lottable09, 
          @c_Lottable10 = LA.Lottable10, 
          @c_Lottable11 = LA.Lottable11, 
          @c_Lottable12 = LA.Lottable12, 
          @n_LotQty = (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)          
   FROM LOTxLOCxID AS LLI WITH(NOLOCK) 
   JOIN LOTATTRIBUTE AS LA WITH(NOLOCK) ON LA.Lot = LLI.Lot 
   WHERE LLI.Lot = @c_LOT
   AND LLI.Loc   = @c_LOC
   AND LLI.Id    = @c_ID 
   
   IF @n_LotQty <= 0 
   BEGIN
      SET @n_Continue = 4
   END

   SET @c_ForceAllocLottable = '0'  

   SELECT @c_ForceAllocLottable = ISNULL(sValue,'0')  
   FROM   StorerConfig WITH (NOLOCK)
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'ForceAllocLottable'
   
   IF @c_ForceAllocLottable = '1'
   BEGIN
      SELECT TOP 1 @c_ForceLottableList = NOTES
      FROM CODELKUP (NOLOCK)
      WHERE Storerkey = @c_StorerKey
      AND Listname = 'FORCEALLOT'

      IF ISNULL(@c_ForceLottableList,'') = ''
         SET @c_ForceLottableList = 'LOTTABLE01,LOTTABLE02,LOTTABLE03'     
   END
                     
   IF @n_Continue=1 or @n_Continue=2
   BEGIN
      DECLARE @c_Authority NVARCHAR(1)

      SELECT @b_Success = 0
      EXECUTE nspGetRight '',
      @c_StorerKey,   -- Storer
      '',             -- Sku
      'OWITF',        -- ConfigKey
      @b_Success          OUTPUT,
      @c_Authority        OUTPUT,
      @n_ErrNo            OUTPUT,
      @c_ErrMsg           OUTPUT

      IF @c_Authority = '1'
         SELECT @n_Continue = 3
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF NOT EXISTS ( SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC  )
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey 
                    AND SKUxLOC.Sku = @c_SKU
                    AND SKUxLOC.LOC = @c_LOC
                    AND SKUxLOC.LocationType IN ('PICK', 'CASE') ) AND
         NOT EXISTS (
                     SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC )
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey
                    AND SKUxLOC.Sku = @c_SKU
                    AND SKUxLOC.LOC = @c_LOC                    
                    AND  SKUxLOC.QtyExpected = 0  ) AND
         NOT EXISTS ( SELECT  1 FROM SKUxLOC WITH (NOLOCK)
                    JOIN LOTxLOCxID  WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey
                               AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC )
                    JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey
                    AND SKUxLOC.Sku = @c_SKU
                    AND SKUxLOC.LOC = @c_LOC                    
                    AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK') )
      BEGIN
         SELECT @n_Continue = 4
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      WHILE @n_LotQty >= 0
      BEGIN
         SET @c_ReplenLOT = ''
         SET @c_ReplenID  = ''
         
         SELECT TOP 1
                  @c_ReplenLOT = LOTxLOCxID.Lot,
                  @c_ReplenID  = LOTxLOCxID.ID,
                  @n_ReplenQty = (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty 
         FROM  LOTxLOCxID WITH (NOLOCK)
         WHERE LOTxLOCxID.Loc = @c_LOC
         AND   LOTxLOCxID.LOT = @c_LOT
         AND   LOTxLOCxID.ID <> @c_ID
         AND   LOTxLOCxID.Qty < (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)
         ORDER BY LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked DESC
         IF @@ROWCOUNT = 0
         BEGIN
            GET_NEXT_LOT:

            SET @n_RowCount=0

            IF ISNULL(RTRIM(@c_ForceAllocLottable),'0') = '1'
            BEGIN
               -- Not Allow to swap HELD Lot and ID
               SELECT @c_SQLSelect =
               N'SELECT TOP 1 
                        @c_ReplenLOT = LOTxLOCxID.Lot,
                        @c_ReplenID  = LOTxLOCxID.ID, 
                        @n_ReplenQty = (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty
                  FROM  LOTxLOCxID WITH (NOLOCK)
                  JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                  JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                  WHERE LOTxLOCxID.LOT <> @c_LOT
                  AND   LOT.Sku = @c_SKU
                  AND   LOT.StorerKey = @c_StorerKey                  
                  AND   LOTxLOCxID.Loc = @c_LOC
                  AND   LOTxLOCxID.Qty < (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)
                  AND   LOT.LOT > @c_ReplenLOT ' +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' AND CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' AND CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' AND CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable06),'') <> '' AND CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable06 = @c_Lottable06 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable07),'') <> '' AND CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable07 = @c_Lottable07 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable08),'') <> '' AND CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable08 = @c_Lottable08 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable09),'') <> '' AND CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable09 = @c_Lottable09 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable10),'') <> '' AND CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable10 = @c_Lottable10 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable11),'') <> '' AND CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable11 = @c_Lottable11 ' END +
                  CASE WHEN ISNULL(RTRIM(@c_Lottable12),'') <> '' AND CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 THEN 'AND LOTATTRIBUTE.Lottable12 = @c_Lottable12 ' END +
                  ' ORDER BY LOT.LOT '                    --(Wan01)
            END
            ELSE
            BEGIN
               SELECT @c_SQLSelect =
               N'SELECT TOP 1 
                        @c_ReplenLOT = LOTxLOCxID.Lot,
                        @c_ReplenID  = LOTxLOCxID.ID, 
                        @n_ReplenQty = (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked) - LOTxLOCxID.Qty
                  FROM  LOTxLOCxID WITH (NOLOCK) 
                  JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT 
                  JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                  WHERE LOTxLOCxID.LOT <> @c_LOT
                  AND   LOT.StorerKey = @c_StorerKey                  
                  AND   LOT.Sku       = @c_SKU
                  AND   LOTxLOCxID.Loc= @c_LOC
                  AND   LOTxLOCxID.Qty < (LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked)
                  AND   LOT.LOT > @c_ReplenLOT 
                  ORDER BY LOT.LOT '                      
            END

            -- SET @c_ReplenLOT = ''
            SET @c_ReplenID  = ''
            SET @n_ReplenQty = 0
            EXEC sp_executesql @c_SQLSelect, N'@c_StorerKey  NVARCHAR(15)
                                             , @c_LOC        NVARCHAR(10)
                                             , @c_SKU        NVARCHAR(20)
                                             , @c_LOT        NVARCHAR(10)
                                             , @c_ReplenLOT  NVARCHAR(10) OUTPUT
                                             , @n_ReplenQty  INT          OUTPUT
                                             , @c_ReplenID   NVARCHAR(18) OUTPUT
                                             , @c_Lottable01 NVARCHAR(18)
                                             , @c_Lottable02 NVARCHAR(18)
                                             , @c_Lottable03 NVARCHAR(18)
                                             , @d_Lottable04 DATETIME
                                             , @c_Lottable06 NVARCHAR(30)
                                             , @c_Lottable07 NVARCHAR(30)
                                             , @c_Lottable08 NVARCHAR(30)
                                             , @c_Lottable09 NVARCHAR(30)
                                             , @c_Lottable10 NVARCHAR(30)
                                             , @c_Lottable11 NVARCHAR(30)
                                             , @c_Lottable12 NVARCHAR(30)' --NJOW01
                                             , @c_StorerKey
                                             , @c_LOC
                                             , @c_SKU
                                             , @c_LOT  
                                             , @c_ReplenLOT OUTPUT
                                             , @n_ReplenQty OUTPUT
                                             , @c_ReplenID  OUTPUT
                                             , @c_Lottable01
                                             , @c_Lottable02
                                             , @c_Lottable03
                                             , @d_Lottable04
                                             , @c_Lottable06   
                                             , @c_Lottable07
                                             , @c_Lottable08
                                             , @c_Lottable09
                                             , @c_Lottable10
                                             , @c_Lottable11
                                             , @c_Lottable12

            IF ISNULL(RTRIM(@c_ReplenLOT),'') = '' OR @n_ReplenQty <= 0 
            BEGIN
               IF @b_Debug = 1
               BEGIN
                  PRINT ''
                  PRINT 'No Lot found!'               
               END
               BREAK 
            END                        
         END -- IF @n_RowCount = 0   
         
         IF ISNULL(RTrim(@c_ReplenLOT),'') <> '' AND @n_ReplenQty > 0 
         BEGIN                      
            IF @b_Debug = 1
            BEGIN
               PRINT ''
               PRINT 'LOT: ' + @c_ReplenLOT 
               PRINT 'ID:  ' + @c_ReplenID
            END
            
            DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT [Priority] = CASE   WHEN SO.OrderKey = @c_OrderKey THEN 1
                                       WHEN SO.LoadKey = @c_LoadKey THEN 2 
                                       WHEN PD.[Status] > '4' THEN 3
                                       ELSE 9 
                                       END     
                  , PD.PickDetailKey 
                  , PD.ID 
                  , PD.Qty 
                  , PD.ShipFlag 
                  , OD.Lottable01   
                  , OD.Lottable02   
                  , OD.Lottable03   
                  , OD.Lottable06   
                  , OD.Lottable07   
                  , OD.Lottable08   
                  , OD.Lottable09   
                  , OD.Lottable10   
                  , OD.Lottable11   
                  , OD.Lottable12 
                  , lli.Qty - lli.QtyPicked
            FROM PICKDETAIL PD WITH (NOLOCK) 
            JOIN ORDERS AS SO WITH(NOLOCK) ON PD.OrderKey = SO.OrderKey 
            JOIN ORDERDETAIL OD WITH(NOLOCK) ON SO.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber 
            JOIN LOTxLOCxID lli (NOLOCK) ON lli.lot = pd.lot AND lli.Loc = pd.loc AND lli.Id = pd.ID
            WHERE PD.SKU        = @c_SKU
               AND PD.StorerKey = @c_StorerKey
               AND PD.LOC       = @c_LOC
               AND PD.LOT       = @c_ReplenLOT
               AND PD.ShipFlag  <> 'Y' 
               AND PD.[Status]  < '5' 
               AND lli.Qty - lli.QtyPicked >= 0
            ORDER BY [Priority], PD.PickDetailKey 
              
            OPEN PICK_CUR

            FETCH NEXT FROM PICK_CUR INTO @n_Priority, @c_PickDetailKey, @c_ID_pd, @n_Qty, @c_ShipFlag 
                                       ,  @c_ODLottable01, @c_ODLottable02, @c_ODLottable03
                                       ,  @c_ODLottable06, @c_ODLottable07, @c_ODLottable08
                                       ,  @c_ODLottable09, @c_ODLottable10, @c_ODLottable11
                                       ,  @c_ODLottable12, @n_Qty_OpenAvail   
             
            SET @n_FetchStatus = @@FETCH_STATUS
         
            IF @n_FetchStatus = -1
            BEGIN
               IF CURSOR_STATUS('local','PICK_CUR') = 1    
                  CLOSE PICK_CUR    
                       
               IF CURSOR_STATUS('local','PICK_CUR') = -1    
                  DEALLOCATE PICK_CUR    
               
               IF @b_Debug=1
               BEGIN
                  PRINT 'No Pick Detail Found!'
               END   
               
               GOTO GET_NEXT_LOT        
            END
         
            WHILE (@n_FetchStatus <> -1)
            BEGIN
               SET @n_RowCount = 0
               SELECT @n_RowCount = 1
                    , @n_QtyAvail = lli.QtyAvail
               FROM #LOTxLOCxID lli 
               WHERE lli.Lot = @c_ReplenLOT
               AND   lli.Loc = @c_Loc
               AND   lli.ID  = @c_ID_pd

               IF @n_RowCount = 0 
               BEGIN
                  SET @n_QtyAvail = @n_Qty_OpenAvail
                  INSERT INTO #LOTxLOCxID ( Lot, Loc, Id, QtyAvail )
                  SELECT @c_ReplenLOT, @c_Loc, @c_ID_pd, @n_Qty_OpenAvail - @n_Qty
               END
               ELSE
               BEGIN
                  UPDATE #LOTxLOCxID SET QtyAvail = QtyAvail - @n_Qty
                  WHERE Lot = @c_ReplenLOT
                  AND   Loc = @c_Loc
                  AND   ID  = @c_ID_pd
               END
               
               IF @n_Qty <= @n_QtyAvail AND @n_QtyAvail > 0
               BEGIN
                  GOTO SKIP_NEXT
               END

               IF @b_Debug = 1
               BEGIN
                  PRINT ''
                  PRINT 'PickDetailKey : ' + @c_PickDetailKey 
                  PRINT 'PD Qty        : ' + CAST(@n_Qty AS VARCHAR(10)) 
               END
               
               IF ISNULL(RTRIM(@c_ForceAllocLottable),'0') = '1'
               BEGIN
                  IF (CHARINDEX('LOTTABLE01', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable01,'') <> '' AND ISNULL(@c_ODLottable01,'') <> ISNULL(@c_Lottable01,'')) 
                      OR (CHARINDEX('LOTTABLE02', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable02,'') <> '' AND ISNULL(@c_ODLottable02,'') <> ISNULL(@c_Lottable02,''))
                      OR (CHARINDEX('LOTTABLE03', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable03,'') <> '' AND ISNULL(@c_ODLottable03,'') <> ISNULL(@c_Lottable03,''))
                      OR (CHARINDEX('LOTTABLE06', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable06,'') <> '' AND ISNULL(@c_ODLottable06,'') <> ISNULL(@c_Lottable06,''))
                      OR (CHARINDEX('LOTTABLE07', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable07,'') <> '' AND ISNULL(@c_ODLottable07,'') <> ISNULL(@c_Lottable07,''))
                      OR (CHARINDEX('LOTTABLE08', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable08,'') <> '' AND ISNULL(@c_ODLottable08,'') <> ISNULL(@c_Lottable08,''))
                      OR (CHARINDEX('LOTTABLE09', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable09,'') <> '' AND ISNULL(@c_ODLottable09,'') <> ISNULL(@c_Lottable09,''))
                      OR (CHARINDEX('LOTTABLE10', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable10,'') <> '' AND ISNULL(@c_ODLottable10,'') <> ISNULL(@c_Lottable10,''))
                      OR (CHARINDEX('LOTTABLE11', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable11,'') <> '' AND ISNULL(@c_ODLottable11,'') <> ISNULL(@c_Lottable11,''))
                      OR (CHARINDEX('LOTTABLE12', @c_ForceLottableList) > 0 AND ISNULL(@c_ODLottable12,'') <> '' AND ISNULL(@c_ODLottable12,'') <> ISNULL(@c_Lottable12,''))
                  BEGIN
                     GOTO SKIP_NEXT
                  END
               END
                           
               SET @n_LOTQty2=0

               SELECT @n_LOTQty2 = LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated  -- tlting01
               FROM LOT  With (NOLOCK)         
               WHERE  LOT = @c_LOT
               AND LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0

               IF @n_LOTQty2 < @n_ReplenQty
                  SET @n_ReplenQty = @n_LOTQty2

               IF @n_ReplenQty = 0
               BEGIN
                  IF CURSOR_STATUS('local','PICK_CUR') = 1
                     CLOSE PICK_CUR
                     
                  IF CURSOR_STATUS('local','PICK_CUR') = -1
                     DEALLOCATE PICK_CUR
                     
                  GOTO GET_NEXT_LOT                
               END
                  

               IF @b_Debug = 1
               BEGIN
                  PRINT 'Replen Qty    : ' + CAST(@n_ReplenQty AS VARCHAR(10)) 
               END
                         
               IF @n_ReplenQty >= @n_Qty
               BEGIN
                  BEGIN TRAN

                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Lot = @c_LOT,
                      ID  = @c_ID,
                      EditWho = SUSER_SNAME(), 
                      EditDate = GETDATE()
                  WHERE PickDetailKey = @c_PickDetailKey 

                  SELECT @n_ErrNo = @@ERROR

                  IF @n_ErrNo <> 0
                  BEGIN
                     IF @b_Debug = 1
                     BEGIN
                        SELECT @c_SKU 'sku', @c_LOC 'loc', @c_ReplenLOT 'new lot', @c_PickDetailKey 'pickdetailkey'
                     END
                     
                     ROLLBACK TRAN
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
                  
                  SET @n_LotQty = @n_LotQty - @n_Qty
                  SET @n_ReplenQty = @n_ReplenQty - @n_Qty 
                  
                  -- Added By SHONG on 15-Feb-2005
                  IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) 
                            WHERE LOC = @c_LOC  
                            AND   LOT = @c_LOT
                            AND   ID = @c_ID 
                            AND ( Qty > QtyPicked + QtyAllocated) )
                  BEGIN
                     BEGIN TRAN

                     UPDATE LOTxLOCxID WITH (ROWLOCK)
                        SET QtyExpected = 0
                     WHERE LOT = @c_LOT
                     AND   LOC = @c_LOC
                     AND   ID = @c_ID
                     AND ( Qty >= QtyPicked + QtyAllocated )
                     IF @@ERROR <> 0
                     BEGIN
                        ROLLBACK TRAN
                     END
                     ELSE
                     BEGIN
                        COMMIT TRAN
                     END
                  END
               END -- If lot qty > pick qty
               ELSE -- Split PickDetail
               BEGIN
                  SET @b_Success = 0

                  EXECUTE   nspg_getkey
                        'PickDetailKey'
                        , 10
                        , @c_NewPickDetailKey OUTPUT
                        , @b_Success OUTPUT
                        , @n_ErrNo OUTPUT
                        , @c_ErrMsg OUTPUT

                  IF @b_Debug = 1
                  BEGIN
                     PRINT '>>> Split PickDetail '
                     PRINT 'New PD Key    : ' + @c_NewPickDetailKey
                  END      
               
                  IF @b_Success = 1
                  BEGIN
                     BEGIN TRAN

                     UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET Qty = Qty - @n_ReplenQty,
                            EditWho = SUSER_SNAME(), 
                            EditDate = GETDATE()
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR = 0
                     BEGIN
                        INSERT PICKDETAIL
                           (PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber,
                              Lot,           StorerKey,     Sku,           Qty,
                              Loc,           Id,            UOMQty,        UOM,
                              CaseID,        PackKey,       CartonGroup,   DoReplenish,
                              Replenishzone, docartonize,   Trafficcop,    PickMethod,
                              Status,        PickSlipNo,    AddWho,        EditWho,
                              ShipFlag,      DropID,        TaskDetailKey, AltSKU,
                              ToLoc,         Notes,         MoveRefKey,    Channel_ID)
                        SELECT @c_NewPickDetailKey,  PickHeaderKey,    OrderKey,     OrderLineNumber,
                               @c_LOT,          StorerKey,    Sku,            @n_ReplenQty,
                               Loc,             @c_ID,        UOMQty,         UOM,
                               CaseID,          PackKey,      CartonGroup,    DoReplenish,
                               replenishzone,   docartonize,  Trafficcop,     PickMethod,
                               '0',             PickSlipNo,   SUSER_SNAME(),  SUSER_SNAME(),
                               @c_ShipFlag,     DropID,       TaskDetailKey,  AltSku,
                               ToLoc,           Notes,        MoveRefKey,     Channel_ID
                        FROM   PICKDETAIL (NOLOCK)
                        WHERE  PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                        BEGIN
                           ROLLBACK TRAN
                        END                        
                        ELSE
                        BEGIN
                           -- Insert into RefKeyLookup for newly added Pickdetail Record.
                           IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @c_PickDetailKey)
                           BEGIN
                              INSERT INTO RefKeyLookup
                              (
                                 PickDetailkey,
                                 Pickslipno,
                                 OrderKey,
                                 OrderLineNumber,
                                 Loadkey
                              )
                              SELECT @c_NewPickDetailKey,
                                       rkl.Pickslipno,
                                       rkl.OrderKey,
                                       rkl.OrderLineNumber,
                                       rkl.Loadkey
                                 FROM RefKeyLookup rkl
                              WHERE rkl.PickDetailkey = @c_PickDetailKey
                           END
                           
                           SELECT @c_Status = STATUS
                           FROM   PICKDETAIL WITH (NOLOCK)
                           WHERE  PickDetailKey = @c_PickDetailKey

                           IF @c_Status <> '0'
                           BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET STATUS = @c_Status
                              WHERE  PickDetailKey = @c_NewPickDetailKey
                              AND    STATUS <> @c_Status                            
                           END
                           COMMIT TRAN
                           SELECT @n_rows = @n_rows + 1
                        END
                     END -- IF @@ERROR = 0
                     SET @n_LotQty = @n_LotQty - @n_ReplenQty
                     SET @n_ReplenQty = 0                   
                  END -- IF @b_Success = 1 
               END -- -- Split PickDetail
            
               IF @n_LotQty = 0 
                  BREAK
                
               SKIP_NEXT:
               FETCH NEXT FROM PICK_CUR INTO @n_Priority, @c_PickDetailKey, @c_ID_pd, @n_Qty, @c_ShipFlag 
                                          ,  @c_ODLottable01, @c_ODLottable02, @c_ODLottable03
                                          ,  @c_ODLottable06, @c_ODLottable07, @c_ODLottable08
                                          ,  @c_ODLottable09, @c_ODLottable10, @c_ODLottable11
                                          ,  @c_ODLottable12, @n_Qty_OpenAvail   
               SET @n_FetchStatus = @@FETCH_STATUS
            END -- While Cursor Loop 

            CLOSE PICK_CUR 
            DEALLOCATE PICK_CUR   
            
            IF @n_ReplenQty > 0
            BEGIN
               GOTO GET_NEXT_LOT       
            END 
         END -- IF ISNULL(RTrim(@c_ReplenLOT),'') <> '' AND @n_ReplenQty > 0 
         ELSE 
            BREAK 
      END  -- WHILE @n_LotQty >= 0           
   END -- @n_Continue = 1

   QUIT:

   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
   END
   ELSE
   BEGIN 
      SET @b_Success = 1
   END
END

GO