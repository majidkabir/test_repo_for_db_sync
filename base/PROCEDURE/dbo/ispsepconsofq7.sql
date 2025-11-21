SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispSEPConsoFQ7                                          */
/* Creation Date: 2020-09-08                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13192 - [CN] Sephora_WMS_AllocationStrategy             */
/*        : Full DPP Qty PickCode                                       */
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
/* 2022-11-14  Wan01    1.1   Sync filter Start Point/Enhancement       */
/* 2022-11-14  Wan01    1.1   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[ispSEPConsoFQ7]
     @c_WaveKey            NVARCHAR(10)
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
   , @dt_InvLot04          DATETIME = NULL
   , @c_WaveType           NVARCHAR(10) = ''
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

         , @c_LocationType       NVARCHAR(10) = ''      
         , @c_LocationCategory   NVARCHAR(10) = ''
         , @c_UOM                NVARCHAR(10) = '7'
         , @c_PickMethod         NVARCHAR(10) = ''

         , @dt_Lottable13_1      DATETIME     
         , @dt_Lottable13_2      DATETIME
         , @d_today              DATETIME = CONVERT(NVARCHAR(10), GETDATE(), 121)

         , @n_TotalExpiryDay     INT          = 0

         , @c_Lot                NVARCHAR(10) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @n_QtyAvailable       INT          = 0

         , @n_RowID              INT          = 0
         , @n_Status             INT          = 0
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_OrderLineNumber    NVARCHAR(5)  = ''
         , @c_PickDetailkey      NVARCHAR(10) = ''
         , @c_PackKey            NVARCHAR(10) = ''
         , @n_UOMQty             INT          = 0
         , @n_Shelflife          INT          = 0
         , @n_OrderQty           INT          = 0
         , @n_QtyToInsert        INT          = 0

         , @c_SQL                NVARCHAR(4000) = ''
         , @c_SQLParms           NVARCHAR(4000) = ''

         , @CUR_LLI              CURSOR
         , @CUR_OD               CURSOR

   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_LocationCategory = 'SHELVING'
   SET @c_LocationType     = 'DYNPPICK'      

   IF OBJECT_ID('tempdb..#LOTxLOCxID','U') IS NOT NULL
   BEGIN
      DROP TABLE #LOTxLOCxID;
   END

   CREATE TABLE #LOTxLOCxID
      (  RowID          INT            IDENTITY(1,1) PRIMARY KEY
      ,  Lot            NVARCHAR(10)   NOT NULL DEFAULT('')   
      ,  Loc            NVARCHAR(10)   NOT NULL DEFAULT('')
      ,  ID             NVARCHAR(18)   NOT NULL DEFAULT('')
      ,  QtyAvailable   INT            NOT NULL DEFAULT(0)
      ,  ExpiryDate     DATETIME       NULL
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
   IF ISNULL(@dt_InvLot04, '1900-01-01') <> '1900-01-01'  
   BEGIN
      SET @n_TotalExpiryDay = DATEDIFF(day, GETDATE(), @dt_InvLot04)
   END

   IF @b_debug IN (1,9)
   BEGIN
      PRINT '---------------------------------------'+ CHAR(13) +
            'Sub PICKCOde: ispSEPConsoFQ7'+ CHAR(13) +
            'Facility: ' + @c_Facility + CHAR(13) +
            'Storekrey: ' + @c_Storerkey + CHAR(13) +
            'SKU: ' + @c_SKU + CHAR(13) +
            'LocationType: ' + @c_LocationType + CHAR(13) +
            'LocationCategory: ' + @c_LocationCategory + CHAR(13) +
            '@n_QtyLeftToFullFill: ' + CAST(@n_QtyLeftToFullFill AS VARCHAR) + CHAR(13) +
            '@n_TotalExpiryDay: ' + + CAST(@n_TotalExpiryDay AS VARCHAR) + CHAR(13) +
            '@dt_InvLot04: ' + + CONVERT(VARCHAR(20),@dt_InvLot04, 106) + CHAR(13) +
            '@c_Lottable01: ' + @c_Lottable01 + CHAR(13) +
            '@c_Lottable02: ' + @c_Lottable02 + CHAR(13) +
            '@c_Lottable03: ' + @c_Lottable03 + CHAR(13) +
            '@c_Lottable06: ' + @c_Lottable06 + CHAR(13) +
            '@c_Lottable07: ' + @c_Lottable07 + CHAR(13) +
            '@c_Lottable08: ' + @c_Lottable08 + CHAR(13) +
            '@c_Lottable10: ' + @c_Lottable10 + CHAR(13) +
            '@c_Lottable09: ' + @c_Lottable09 + CHAR(13) +
            '@c_Lottable11: ' + @c_Lottable11 + CHAR(13) +
            '@c_Lottable12: ' + @c_Lottable12 + CHAR(13) +
            '@dt_Lottable13_1: ' + CASE WHEN @dt_Lottable13_1 IS NULL THEN 'NULL' ELSE CONVERT(VARCHAR(20),@dt_Lottable13_1, 106) END+ CHAR(13) +
            '@dt_Lottable13_2: ' + CASE WHEN @dt_Lottable13_2 IS NULL THEN 'NULL' ELSE CONVERT(VARCHAR(20),@dt_Lottable13_2, 106) END + CHAR(13) +
            '@c_WaveType: ' + @c_WaveType + CHAR(13)
   END

  ;WITH ORD AS
   (  SELECT Loadkey = ''
            ,OH.Orderkey
            ,OrderInfo04 = CASE WHEN ISNUMERIC(OIF.OrderInfo04) = 1 
                                THEN CONVERT(INT,OIF.OrderInfo04) 
                                ELSE 0 
                                END
      FROM WAVE        WH WITH (NOLOCK)
      JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey  = WD.Wavekey
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      LEFT OUTER JOIN ORDERINFO OIF WITH (NOLOCK) ON OH.Orderkey = OIF.Orderkey
      WHERE WH.Wavekey = @c_WaveKey
      AND OH.[Type] NOT IN ( 'M', 'I' )   
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
         ,ShelfLife = ISNULL(OD.MinShelfLife,0) + OH.OrderInfo04
         ,OrderQty =(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked))
   FROM ORD         OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   WHERE  OD.Storerkey = @c_Storerkey
      AND OD.Sku = @c_Sku  
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked)) > 0
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked)) <= @n_QtyLeftToFullFill
      AND OD.Lottable01 = @c_Lottable01
      AND OD.Lottable02 = @c_Lottable02
      AND OD.Lottable03 = @c_Lottable03
      AND OD.Lottable06 = @c_Lottable06
      AND OD.Lottable07 = @c_Lottable07
      AND OD.Lottable08 = @c_Lottable08
      AND OD.Lottable09 = @c_Lottable09
      AND OD.Lottable10 = @c_Lottable10
      AND OD.Lottable11 = @c_Lottable11
      AND OD.Lottable12 = @c_Lottable12
      AND OD.Lottable13 IN ( @dt_Lottable13_1, @dt_Lottable13_2 )
      AND (@n_TotalExpiryDay = 0 OR ISNULL(OD.MinShelfLife,0) + OH.OrderInfo04 <= @n_TotalExpiryDay)
   ORDER BY OH.Loadkey
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

   SET @c_SQL = N'INSERT INTO #LOTxLOCxID ( Lot, Loc, ID, QtyAvailable, ExpiryDate )'
   + ' SELECT LLI.Lot, LLI.Loc, LLI.ID'
   + ' ,QtyAvailable = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked'
   + ' ,ExpiryDate = LA.Lottable04'
   + ' FROM LOTxLOCxID LLI  WITH (NOLOCK)'
   + ' JOIN LOT             WITH (NOLOCK) ON LLI.Lot = LOT.Lot AND LOT.[Status] = ''OK'''
   + ' JOIN LOC             WITH (NOLOCK) ON LLI.Loc = LOC.Loc AND LOC.[Status] = ''OK'''
   + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LLI.Lot = LA.Lot' 
   + ' WHERE LA.Storerkey = @c_Storerkey'             --(Wan01)
   + ' AND   LA.Sku       = @c_Sku'                   --(Wan01)
   + CASE WHEN ISNULL(@c_Lottable01,'') = '' THEN '' ELSE ' AND LA.Lottable01 = @c_Lottable01' END
   + CASE WHEN ISNULL(@c_Lottable02,'') = '' THEN '' ELSE ' AND LA.Lottable02 = @c_Lottable02' END
   + CASE WHEN ISNULL(@c_Lottable03,'') = '' THEN '' ELSE ' AND LA.Lottable03 = @c_Lottable03' END
   + ' AND LA.Lottable04 = @dt_InvLot04'
   --+ CASE WHEN @c_WaveType IN ('SEPB2CAGV','SEPB2B_AGV') THEN '' ELSE ' AND LA.Lottable04 = @dt_InvLot04'  END
   + CASE WHEN ISNULL(@c_Lottable06,'') = '' THEN '' ELSE ' AND LA.Lottable06 = @c_Lottable06' END
   + CASE WHEN ISNULL(@c_Lottable07,'') = '' THEN '' ELSE ' AND LA.Lottable07 = @c_Lottable07' END
   + CASE WHEN ISNULL(@c_Lottable08,'') = '' THEN '' ELSE ' AND LA.Lottable08 = @c_Lottable08' END
   + CASE WHEN ISNULL(@c_Lottable09,'') = '' THEN '' ELSE ' AND LA.Lottable09 = @c_Lottable09' END
   + CASE WHEN ISNULL(@c_Lottable10,'') = '' THEN '' ELSE ' AND LA.Lottable10 = @c_Lottable10' END
   + CASE WHEN ISNULL(@c_Lottable11,'') = '' THEN '' ELSE ' AND LA.Lottable11 = @c_Lottable11' END
   + CASE WHEN ISNULL(@c_Lottable12,'') = '' THEN '' ELSE ' AND LA.Lottable12 = @c_Lottable12' END
   + CASE WHEN ISNULL(@dt_Lottable13,'1900-01-01') = '1900-01-01' THEN '' ELSE ' AND LA.Lottable13 = @dt_Lottable13' END
   +' AND   LOC.Facility  = @c_Facility'
   +' AND   LOC.LocationCategory = @c_LocationCategory'
   +' AND   LOC.LocationType = @c_LocationType'
   +' AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0'                             
   +' AND   LA.Lottable04 > @d_today'
   +' ORDER BY LA.Lottable04, LLI.Lot'

   SET @c_SQLParms  = N' @c_Facility           NVARCHAR(5)'  
                    + ', @c_Storerkey          NVARCHAR(15)' 
                    + ', @c_Sku                NVARCHAR(20)' 
                    + ', @c_Lottable01         NVARCHAR(18)'     
                    + ', @c_Lottable02         NVARCHAR(18)'  
                    + ', @c_Lottable03         NVARCHAR(18)' 
                    + ', @c_Lottable06         NVARCHAR(30)' 
                    + ', @c_Lottable07         NVARCHAR(30)' 
                    + ', @c_Lottable08         NVARCHAR(30)' 
                    + ', @c_Lottable09         NVARCHAR(30)' 
                    + ', @c_Lottable10         NVARCHAR(30)' 
                    + ', @c_Lottable11         NVARCHAR(30)' 
                    + ', @c_Lottable12         NVARCHAR(30)' 
                    + ', @dt_Lottable13        DATETIME'  
                    + ', @dt_InvLot04          DATETIME'
                    + ', @c_LocationType       NVARCHAR(10)'      
                    + ', @c_LocationCategory   NVARCHAR(10)'                 
                    + ', @n_QtyLeftToFullfill  INT' 
                    + ', @d_today              DATETIME' 
      
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms 
                     , @c_Facility           
                     , @c_Storerkey         
                     , @c_Sku               
                     , @c_Lottable01        
                     , @c_Lottable02        
                     , @c_Lottable03        
                     , @c_Lottable06        
                     , @c_Lottable07        
                     , @c_Lottable08        
                     , @c_Lottable09        
                     , @c_Lottable10        
                     , @c_Lottable11        
                     , @c_Lottable12        
                     , @dt_Lottable13       
                     , @dt_InvLot04   
                     , @c_LocationType            
                     , @c_LocationCategory                       
                     , @n_QtyLeftToFullfill  
                     , @d_today     

   IF @b_debug IN (1, 2,9)
   BEGIN
      PRINT @c_SQL
      SELECT LLI.Lot 
         ,LLI.Loc
         ,LLI.ID
         ,LLI.QtyAvailable
         ,LLI.ExpiryDate
      FROM #LOTxLOCxID LLI
      ORDER BY LLI.RowID
   END

   SET @CUR_LLI = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT LLI.Lot 
         ,LLI.Loc
         ,LLI.ID
         ,LLI.QtyAvailable
         ,LLI.ExpiryDate
   FROM #LOTxLOCxID LLI
   ORDER BY LLI.RowID

   OPEN @CUR_LLI

   FETCH NEXT FROM @CUR_LLI INTO @c_Lot 
                              ,  @c_Loc
                              ,  @c_ID
                              ,  @n_QtyAvailable
                              ,  @dt_InvLot04
   
   WHILE @@FETCH_STATUS <> -1 AND  @n_QtyLeftToFullFill > 0
   BEGIN
      IF @b_debug IN ( 1, 9)
      BEGIN
         PRINT 'SKU: ' + @c_SKU + CHAR(13) +
               '@n_QtyLeftToFullFill: ' + CAST(@n_QtyLeftToFullFill AS VARCHAR) + CHAR(13) 
      END
   
      SET @n_TotalExpiryDay = 0
      IF ISNULL(@dt_InvLot04, '1900-01-01') <> '1900-01-01'  
      BEGIN
         SET @n_TotalExpiryDay = DATEDIFF(day, GETDATE(), @dt_InvLot04)
      END

      SET @CUR_OD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OL.RowID
            ,OD.Orderkey
            ,OD.OrderLineNumber
            ,OrderQty = (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked ))
      FROM #ORDLINE    OL WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OL.Orderkey = OD.Orderkey 
                                       AND OL.OrderLineNumber = OD.OrderLineNumber
      WHERE OL.Wavekey= @c_Wavekey
      AND  OL.[Status]= 0
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )) > 0
      AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )) <= @n_QtyLeftToFullFill
      AND (@n_TotalExpiryDay = 0 OR OL.ShelfLife <= @n_TotalExpiryDay)
      ORDER BY OL.RowID

      OPEN @CUR_OD
   
      FETCH NEXT FROM @CUR_OD INTO @n_RowID, @c_Orderkey, @c_OrderlineNumber, @n_OrderQty
       
      WHILE @@FETCH_STATUS <> -1 AND @n_QtyLeftToFullFill > 0 AND @n_QtyAvailable > 0
      BEGIN
         SET @n_Status = 0

         IF @n_OrderQty <= @n_QtyAvailable
         BEGIN 
            SET @n_QtyToInsert = @n_OrderQty
         END
         ELSE
         BEGIN
            SET @n_QtyToInsert = @n_QtyAvailable
         END

         IF @n_QtyToInsert > 0
         BEGIN
            -- INSERT PICKDETAIL
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
                              + ': Get PickDetailKey Failed. (ispSEPConsoFQ7)'
               GOTO QUIT_SP
            END

            SET @c_PickMethod = ''  
            SELECT @c_PickMethod = UOM3PickMethod -- piece        
            FROM LOC  WITH (NOLOCK)  
            JOIN PUTAWAYZONE WITH (NOLOCK) ON (LOC.Putawayzone = PUTAWAYZONE.Putawayzone)    
            WHERE LOC.LOC = @c_Loc 

            SET @n_UOMQty = @n_QtyToInsert

            IF @b_debug IN (1,9)
            BEGIN
               PRINT 'PickDetailKey: ' + @c_PickDetailKey + CHAR(13) +
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
                     'InvLot04: ' + CONVERT( NVARCHAR(20), @dt_InvLot04, 121)
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
                  @c_Lot, @c_StorerKey, @c_SKU, @c_UOM, @n_UOMQty, @n_QtyToInsert, '',
                  @c_Loc, @c_ID, @c_PackKey, '', 'N',  
                  '', NULL, 'U', @c_PickMethod,
                  @c_Wavekey
                  )  
                  
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 81220
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                              + ': Insert PickDetail Failed. (ispSEPConsoFQ7)'
               GOTO QUIT_SP
            END

            IF @b_debug IN ( 1, 9)
            BEGIN
               PRINT 'PICKDETAIL INSERTED'
            END
            
            SET @n_OrderQty = @n_OrderQty - @n_QtyToInsert
            SET @n_QtyAvailable = @n_QtyAvailable - @n_QtyToInsert
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
      
      FETCH NEXT FROM @CUR_LLI INTO @c_Lot 
                                 ,  @c_Loc
                                 ,  @c_ID
                                 ,  @n_QtyAvailable
                                 ,  @dt_InvLot04  
   END 
   CLOSE @CUR_LLI
   DEALLOCATE @CUR_LLI
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispSEPConsoFQ7'
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