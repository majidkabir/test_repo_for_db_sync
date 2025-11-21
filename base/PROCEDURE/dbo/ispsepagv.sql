SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispSEPAgv                                               */
/* Creation Date: 2020-05-12                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-13192 - [CN] Sephora_WMS_AllocationStrategy             */
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
/************************************************************************/
CREATE PROC [dbo].[ispSEPAgv]
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
         , @dt_InvLot04          DATETIME

         , @n_QtyLeftToFullFill  INT          = 0

         , @CUR_WVSKU            CURSOR

   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT TOP 1 @c_WaveType = DispatchPiecePickMethod
   FROM WAVE WITH (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF @c_WaveType NOT IN ('SEPB2BPTS','SEPB2CAGV', 'SEPB2CPTS')
   BEGIN
      SET @n_Err = 81010
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                    + ': Invalid Wave Piece Pick Task Dispatch Method'
                    + '. Must Be SEPB2BPTS, SEPB2CAGV or SEPB2CPTS (ispSEPAgv)'
      GOTO QUIT_SP
   END

   IF @c_WaveType IN ('SEPB2CPTS')
   BEGIN
      GOTO QUIT_SP
   END

   IF EXISTS ( SELECT 1 
               FROM WAVEDETAIL WD WITH (NOLOCK)
               LEFT JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON WD.Orderkey = LPD.Orderkey
               WHERE WD.Wavekey = @c_Wavekey
               AND LPD.Loadkey IS NULL
               )
   BEGIN
      SET @n_Err = 81011
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                    + ': Wave has not generate Loadplan yet'
                    + '. Allocation is not allowed (ispSEPAgv)'
      GOTO QUIT_SP
   END
 
   SET @CUR_WVSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OH.Facility
         ,OD.Storerkey
         ,OD.Sku
         ,OD.Lottable01
         ,OD.Lottable02
         ,OD.Lottable03
         ,OD.Lottable06
         ,OD.Lottable07
         ,OD.Lottable08
         ,OD.Lottable09
         ,OD.Lottable10
         ,OD.Lottable11
         ,OD.Lottable12
         ,Lottable13 = ISNULL(OD.Lottable13,'1900-01-01')
         ,ISNULL(SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )),0)
   FROM WAVE        WH WITH (NOLOCK)
   JOIN WAVEDETAIL  WD WITH (NOLOCK) ON WH.Wavekey = WD.Wavekey
   JOIN ORDERS      OH WITH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.Orderkey = OD.Orderkey
   WHERE WH.Wavekey = @c_WaveKey
     AND OH.[Type] NOT IN ( 'M', 'I' )   
     AND OH.SOStatus <> 'CANC'   
     AND OH.[Status] < '9'   
   GROUP BY OH.Facility
         ,  OD.Storerkey
         ,  OD.Sku
         ,  OD.Lottable01
         ,  OD.Lottable02
         ,  OD.Lottable03
         ,  OD.Lottable06
         ,  OD.Lottable07
         ,  OD.Lottable08
         ,  OD.Lottable09
         ,  OD.Lottable10
         ,  OD.Lottable11
         ,  OD.Lottable12
         ,  ISNULL(OD.Lottable13,'1900-01-01')
   HAVING SUM(OD.OpenQty - ( OD.QtyAllocated + OD.QtyPicked )) > 0

   OPEN @CUR_WVSKU
   
   FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility
                                 ,  @c_Storerkey         
                                 ,  @c_Sku               
                                 ,  @c_Lottable01              
                                 ,  @c_Lottable02           
                                 ,  @c_Lottable03        
                                 ,  @c_Lottable06        
                                 ,  @c_Lottable07        
                                 ,  @c_Lottable08        
                                 ,  @c_Lottable09        
                                 ,  @c_Lottable10        
                                 ,  @c_Lottable11        
                                 ,  @c_Lottable12        
                                 ,  @dt_Lottable13 
                                 ,  @n_QtyLeftToFullFill
 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @b_debug IN ( 1, 9 )
      BEGIN
         PRINT '-----------------------------------'+ CHAR(13) +
               'Main PICKCOde: ispSEPAgv'+ CHAR(13) +
               'SKU: ' + @c_SKU + CHAR(13) +
               '@c_WaveKey: ' + @c_WaveKey + CHAR(13) +
               '@c_WaveType: ' + @c_WaveType + CHAR(13) +
               '@n_QtyLeftToFullFill: ' + CAST(@n_QtyLeftToFullFill AS VARCHAR) + CHAR(13)+
               '@dt_Lottable13: ' + CONVERT(NVARCHAR(25), @dt_Lottable13, 121) + CHAR(13)
      END 

      EXEC ispSEPConsoLQ7
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
      , @dt_InvLot04        = @dt_InvLot04        
      , @n_QtyLeftToFullfill= @n_QtyLeftToFullfill OUTPUT
      , @b_Success          = @b_Success           OUTPUT  
      , @n_Err              = @n_Err               OUTPUT  
      , @c_ErrMsg           = @c_ErrMsg            OUTPUT
      , @b_debug            = @b_debug

      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 81020
         SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispSEPConsoLQ7.'
                       + '(ispSEPAgv)' + ' (' + @c_ErrMsg + ')'
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_WVSKU INTO  @c_Facility
                                    ,  @c_Storerkey         
                                    ,  @c_Sku               
                                    ,  @c_Lottable01              
                                    ,  @c_Lottable02           
                                    ,  @c_Lottable03        
                                    ,  @c_Lottable06        
                                    ,  @c_Lottable07        
                                    ,  @c_Lottable08        
                                    ,  @c_Lottable09        
                                    ,  @c_Lottable10        
                                    ,  @c_Lottable11        
                                    ,  @c_Lottable12        
                                    ,  @dt_Lottable13
                                    ,  @n_QtyLeftToFullFill 
   END

   CLOSE @CUR_WVSKU
   DEALLOCATE @CUR_WVSKU  

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispSEPAgv'
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