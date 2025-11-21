SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: ispDesigualB2B                                          */
/* Creation Date: 29-May-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22617 - [CN] Desigual_WMS_AllocationStrategy            */
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
/* 29-May-2023 WLChooi  1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[ispDesigualB2B]
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
         
   SET @b_Success  = 1         
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT TOP 1 @c_WaveType = DispatchPiecePickMethod
   FROM WAVE WITH (NOLOCK)
   WHERE Wavekey = @c_Wavekey

   IF @c_WaveType NOT IN ('DESB2BPTS','DESB2BZINI','DESB2CAGV')
   BEGIN
      SET @n_Err = 82000
      SET @n_Continue = 3
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0))  
                    + ': Invalid Wave Piece Pick Task Dispatch Method'
                    + '. Must Be DESB2CAGV, DESB2BPTS or DESB2BZINI (ispDesigualB2B)'
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
                    + '. Allocation is not allowed (ispDesigualB2B)'
      GOTO QUIT_SP
   END

   IF @c_WaveType NOT IN ('DESB2BPTS','DESB2BZINI')   --Only for B2B
   BEGIN
      GOTO QUIT_SP
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
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         EXEC [dbo].[ispDesigualLoadFP2]   --//Pallet @Pallet LOC
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
         , @b_Debug            = @b_Debug

         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 82020
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispDesigualLoadFP2.'
                          + '(ispDesigualB2B)' + ' (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END

         EXEC [dbo].[ispDesigualLoadFC2]   --//CASE @Case & @Pallet Loc, UOM = '2'
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
         , @b_Debug            = @b_Debug

         IF @b_Success = 0 
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 82030
            SET @c_ErrMsg = ISNULL(ERROR_MESSAGE(),'')
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispDesigualLoadFC2.'
                          + '(ispDesigualB2B)' + ' (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END

         EXEC [dbo].[ispDesigualWaveFP6]   --//Pallet @Pallet LOC, UOM = '6'
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
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispDesigualWaveFP6.'
                          + '(ispDesigualB2B)' + ' (' + @c_ErrMsg + ')'
            GOTO QUIT_SP
         END
         
          EXEC [dbo].[ispDesigualWaveFC6]   --//CASE @Case & @Pallet Loc, UOM = '6'
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
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing ispDesigualWaveFC6.'
                          + '(ispDesigualB2B)' + ' (' + @c_ErrMsg + ')'
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispDesigualB2B'
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