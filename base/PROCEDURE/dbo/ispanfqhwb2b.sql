SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispANFQHWB2B                                            */
/* Creation Date: 2021-03-10                                            */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16267 - [CN] ANFQHW_WMS_AllocationStrategy              */
/*        :                                                             */
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
/************************************************************************/
CREATE PROC [dbo].[ispANFQHWB2B]
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

         , @n_MinShelfLife       INT   = 0
         , @c_WaveType           NVARCHAR(10) = ''

         , @c_Facility           NVARCHAR(5)  = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Orderkey           NVARCHAR(10) = ''
         , @c_OrderLineNumber    NVARCHAR(5)  = ''
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
         , @dt_InvLot04          DATETIME
         , @d_today              DATETIME = CONVERT(NVARCHAR(10), GETDATE(), 121)

         , @n_QtyLeftToFullFill  INT          = 0

         , @c_SQL                NVARCHAR(4000) = ''
         , @c_SQLParms           NVARCHAR(4000) = ''

         , @CUR_WVSKU            CURSOR
         
         , @c_LoadType          NVARCHAR(20)
         , @c_ANFSOType         NVARCHAR(60) 
         , @c_Destination       NVARCHAR(18)
         , @c_Brand             NVARCHAR(18)
         , @c_LocationType      NVARCHAR(10)    
         , @c_LocationCategory  NVARCHAR(10)
         , @n_EnteredQty        INT
         , @n_ThresholdQty      INT
         
         , @c_Channel           NVARCHAR(20)
         
   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT TOP 1 @c_WaveType = DispatchPiecePickMethod
   FROM WAVE WITH (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF @c_WaveType NOT IN ('ANFB2BPTS','ANFB2BAGV','ANFB2CAGV','ANFB2B2DC')
   BEGIN
      SET @n_Err = 82000
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                    + ': Invalid Wave Piece Pick Task Dispatch Method'
                    + '. Must Be ANFB2BPTS, ANFB2BAGV, ANFB2CAGV or ANFB2B2DC (ispANFQHWB2B)'
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1 
               FROM WAVEDETAIL WD WITH (NOLOCK)
               LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON WD.Orderkey = LPD.Orderkey
               WHERE WD.Wavekey = @c_Wavekey
               AND LPD.Loadkey IS NULL
               )
   BEGIN
      SET @n_Err = 82005
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                    + ': Wave has not generate Loadplan yet'
                    + '. Allocation is not allowed (ispANFQHWB2B)'
      GOTO QUIT_SP
   END

   IF @c_WaveType NOT IN ('ANFB2BPTS','ANFB2BAGV','ANFB2B2DC')   --Only for B2B
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1
              FROM WAVEDETAIL WD WITH (NOLOCK)
              JOIN ORDERDETAIL OD WITH (NOLOCK) ON WD.OrderKey = OD.OrderKey
              JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey 
                                              AND PD.OrderLineNumber = OD.OrderLineNumber AND PD.SKU = OD.SKU
   	        WHERE WD.Wavekey = @c_Orderkey)
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 82010
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                         ': Some of the Orders from Wave#' + RTRIM(@c_Wavekey) + ' already allocated. Unable to do rounding (ispANFQHWB2B)'
      GOTO QUIT_SP
   END    
      
   --Reset OrderDetail.OpenQty
   DECLARE CUR_ORDKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT OD.Orderkey, OD.OrderLineNumber
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = WD.OrderKey
   WHERE WD.WaveKey = @c_WaveKey
   
   OPEN CUR_ORDKEY
   
   FETCH NEXT FROM CUR_ORDKEY INTO @c_Orderkey, @c_OrderLineNumber
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET OpenQty = EnteredQty
      WHERE OrderKey = @c_Orderkey AND OrderLineNumber = @c_OrderLineNumber
      
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 82015
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                         ': Update OrderDetail Failed. (ispANFQHWB2B)'
         GOTO QUIT_SP
      END
      
      FETCH NEXT FROM CUR_ORDKEY INTO @c_Orderkey, @c_OrderLineNumber
   END
   CLOSE CUR_ORDKEY
   DEALLOCATE CUR_ORDKEY
   
   --Main QTY Rounding Process
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CURSOR_ORDERLINES CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT OH.Facility,
             OD.StorerKey,
             OD.SKU,
             ISNULL(RTRIM(OD.UserDefine02),''),
             ISNULL(RTRIM(OD.UserDefine01),''),
             OD.Lottable01,
             OD.Lottable02,
             OD.Lottable03,
             SUM(OD.EnteredQty),
             OD.Orderkey,
             OD.OrderLineNumber      
      FROM WAVEDETAIL WD WITH (NOLOCK)  
      JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.OrderKey = OD.OrderKey
      JOIN SKU WITH (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE WD.Wavekey = @c_Wavekey   
        AND OH.[Type] NOT IN ( 'M', 'I' )   
        AND OH.SOStatus <> 'CANC'   
        AND OH.[Status] < '9'   
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
        AND SKU.PrepackIndicator <> 'Y'
      GROUP BY OH.Facility, OD.StorerKey, OD.SKU, ISNULL(RTRIM(OD.UserDefine02),''), 
               ISNULL(RTRIM(OD.UserDefine01),''), OD.Lottable01, OD.Lottable02, OD.Lottable03,
               OD.Orderkey, OD.OrderLineNumber
      
      OPEN CURSOR_ORDERLINES
      FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_Facility, @c_StorerKey, @c_SKU, @c_Destination, @c_Brand, 
                                             @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_EnteredQty,
                                             @c_Orderkey, @c_OrderLineNumber
      
      WHILE (@@FETCH_STATUS <> -1)          
      BEGIN 
         SELECT @n_ThresholdQty = 0, @c_ANFSOType = 'N'
      
         --Get Virtual Rounding Threshold Value
         SELECT @n_ThresholdQty = CODELKUP.UDF01
         FROM CODELKUP WITH (NOLOCK) 
         WHERE Listname = 'VirtualRdg'
           AND Code = @c_Destination + @c_Brand
      
         --GET ANFSOType 
         SELECT @c_ANFSOType = CODELKUP.UDF05
         FROM CODELKUP WITH (NOLOCK)
         WHERE Listname = 'ANFSOtype'
           AND StorerKey + Code = @c_Destination
      
         IF @b_Debug = 1
            PRINT 'Virtual Rounding (' + @c_Destination + ', ' + @c_Brand + ') [' + CAST(@n_EnteredQty AS NVARCHAR) + ']: ' + CHAR(13) + 
                  'ANFSOType: ' + @c_ANFSOType + ', ThresholdQty: ' + CAST(@n_ThresholdQty AS NVARCHAR) + CHAR(13)
      
         IF @n_ThresholdQty > 0 AND ISNULL(@c_ANFSOType,'') = 'Y' 
         BEGIN
            IF @n_EnteredQty < @n_ThresholdQty 
            BEGIN
               UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET OpenQty = @n_ThresholdQty 
               WHERE OrderKey = @c_OrderKey
                 AND OrderLineNumber = @c_OrderLineNumber
      
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 82020
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) + 
                                  ': Update OrderDetail Failed. (ispANFQHWB2B)'
                  GOTO QUIT_SP
               END             
            END          
         END
         
         FETCH NEXT FROM CURSOR_ORDERLINES INTO @c_Facility, @c_StorerKey, @c_SKU, @c_Destination, @c_Brand, 
                                                @c_Lottable01, @c_Lottable02, @c_Lottable03, @n_EnteredQty,
                                                @c_Orderkey, @c_OrderLineNumber
      END -- END WHILE FOR CURSOR_ORDERLINES
      CLOSE CURSOR_ORDERLINES
      DEALLOCATE CURSOR_ORDERLINES
   END
      
   --Main Allocation Process
   IF @n_Continue IN (1,2)
   BEGIN
      SET @CUR_WVSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OH.Facility
            ,OD.Storerkey
            ,OD.Sku
            ,OD.Lottable01
            ,OD.Lottable02
            ,OD.Lottable03
            ,OD.Lottable04
            ,OD.Lottable06
            ,OD.Lottable07
            ,OD.Lottable08
            ,OD.Lottable09
            ,OD.Lottable10
            ,OD.Lottable11
            ,OD.Lottable12
            ,ISNULL(SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )),0)
            ,ISNULL(OD.Channel,'')
      FROM WAVE        WH WITH (NOLOCK)
      JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey
      JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
      WHERE WH.Wavekey = @c_WaveKey
        AND OH.[Type] NOT IN ( 'M', 'I' )   
        AND OH.SOStatus <> 'CANC'   
        AND OH.[Status] < '9'   
        AND (OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
      GROUP BY OH.Facility
            ,  OD.Storerkey
            ,  OD.Sku
            ,  OD.Lottable01
            ,  OD.Lottable02
            ,  OD.Lottable03
            ,  OD.Lottable04
            ,  OD.Lottable06
            ,  OD.Lottable07
            ,  OD.Lottable08
            ,  OD.Lottable09
            ,  OD.Lottable10
            ,  OD.Lottable11
            ,  OD.Lottable12
            ,  ISNULL(OD.Channel,'')
      HAVING SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPreAllocated + OD.QtyPicked )) > 0
      
      OPEN @CUR_WVSKU
      
      FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility
                                    ,  @c_Storerkey         
                                    ,  @c_Sku               
                                    ,  @c_Lottable01              
                                    ,  @c_Lottable02           
                                    ,  @c_Lottable03 
                                    ,  @dt_Lottable04       
                                    ,  @c_Lottable06        
                                    ,  @c_Lottable07        
                                    ,  @c_Lottable08        
                                    ,  @c_Lottable09        
                                    ,  @c_Lottable10        
                                    ,  @c_Lottable11        
                                    ,  @c_Lottable12   
                                    ,  @n_QtyLeftToFullFill
                                    ,  @c_Channel
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC ispANFQHWWaveFP6   --//Pallet @Pallet LOC, UOM = '6'
           @c_WaveKey          = @c_WaveKey         
         , @c_WaveType         = @c_WaveType  
         , @c_Facility         = @c_Facility         
         , @c_Storerkey        = @c_Storerkey        
         , @c_Sku              = @c_Sku              
         , @c_Lottable01       = @c_Lottable01       
         , @c_Lottable02       = @c_Lottable02       
         , @c_Lottable03       = @c_Lottable03       
         , @dt_Lottable04      = @dt_Lottable04      
         , @dt_Lottable05      = @dt_Lottable05      
         , @c_Lottable06       = @c_Lottable06       
         , @c_Lottable07       = @c_Lottable07       
         , @c_Lottable08       = @c_Lottable08       
         , @c_Lottable09       = @c_Lottable09       
         , @c_Lottable10       = @c_Lottable10       
         , @c_Lottable11       = @c_Lottable11       
         , @c_Lottable12       = @c_Lottable12       
         , @dt_Lottable13      = @dt_Lottable13      
         , @dt_Lottable14      = @dt_Lottable14      
         , @dt_Lottable15      = @dt_Lottable15      
         , @c_Channel          = @c_Channel        
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT
         , @b_Success          = @b_Success           OUTPUT  
         , @n_Err              = @n_Err               OUTPUT  
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT
         , @b_Debug            = @b_Debug
         
         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 82020
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispANFQHWWaveFP6.'
                          + '(ispANFQHWB2B)' + ' (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END
         
         --IF @n_QtyLeftToFullfill <= 0
         --BEGIN
         --   GOTO NEXT_INVLOT04
         --END
         
          EXEC ispANFQHWWaveFC6   --//CASE @Case & @Pallet Loc, UOM = '6'
           @c_WaveKey          = @c_WaveKey         
         , @c_WaveType         = @c_WaveType  
         , @c_Facility         = @c_Facility         
         , @c_Storerkey        = @c_Storerkey        
         , @c_Sku              = @c_Sku              
         , @c_Lottable01       = @c_Lottable01       
         , @c_Lottable02       = @c_Lottable02       
         , @c_Lottable03       = @c_Lottable03       
         , @dt_Lottable04      = @dt_Lottable04      
         , @dt_Lottable05      = @dt_Lottable05      
         , @c_Lottable06       = @c_Lottable06       
         , @c_Lottable07       = @c_Lottable07       
         , @c_Lottable08       = @c_Lottable08       
         , @c_Lottable09       = @c_Lottable09       
         , @c_Lottable10       = @c_Lottable10       
         , @c_Lottable11       = @c_Lottable11       
         , @c_Lottable12       = @c_Lottable12       
         , @dt_Lottable13      = @dt_Lottable13      
         , @dt_Lottable14      = @dt_Lottable14      
         , @dt_Lottable15      = @dt_Lottable15      
         , @c_Channel          = @c_Channel        
         , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT
         , @b_Success          = @b_Success           OUTPUT  
         , @n_Err              = @n_Err               OUTPUT  
         , @c_ErrMsg           = @c_ErrMsg            OUTPUT
         , @b_Debug            = @b_Debug
         
         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 82030
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispANFQHWWaveFC6.'
                          + '(ispANFQHWB2B)' + ' (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END
      
         FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility
                                       ,  @c_Storerkey         
                                       ,  @c_Sku               
                                       ,  @c_Lottable01              
                                       ,  @c_Lottable02           
                                       ,  @c_Lottable03 
                                       ,  @dt_Lottable04       
                                       ,  @c_Lottable06        
                                       ,  @c_Lottable07        
                                       ,  @c_Lottable08        
                                       ,  @c_Lottable09        
                                       ,  @c_Lottable10        
                                       ,  @c_Lottable11        
                                       ,  @c_Lottable12   
                                       ,  @n_QtyLeftToFullFill
                                       ,  @c_Channel
      END
      
      CLOSE @CUR_WVSKU
      DEALLOCATE @CUR_WVSKU  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispANFQHWB2B'
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