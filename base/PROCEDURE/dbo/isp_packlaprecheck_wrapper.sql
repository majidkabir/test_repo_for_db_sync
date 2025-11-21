SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackLAPreCheck_Wrapper                              */
/* Creation Date: 2021-12-03                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-18322 - [CN]DYSON_Ecompacking_X708_Function_CR          */
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
/* 2021-12-03  Wan      1.0   Created.                                  */
/* 2021-12-03  Wan      1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_PackLAPreCheck_Wrapper]
     @c_PickSlipNo   NVARCHAR(10)
   , @c_Storerkey    NVARCHAR(15) 
   , @c_Sku          NVARCHAR(20)  
   , @c_TaskBatchNo  NVARCHAR(10)   = ''               
   , @b_Success      INT            = 1   OUTPUT
   , @n_Err          INT            = 0   OUTPUT
   , @c_ErrMsg       NVARCHAR(255)  = ''  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt             INT =  @@TRANCOUNT
         , @n_Continue              INT = 1
         
         , @c_Facility              NVARCHAR(5) = ''
         , @c_PackByLottable        NVARCHAR(30) = ''
         , @c_PackByLottable_Opt05  NVARCHAR(500)= ''         
         , @c_PrePackLACheck_SP     NVARCHAR(30) = ''

         , @c_SQL                   NVARCHAR(1000) = ''
         , @c_SQLParms              NVARCHAR(1000) = ''  
                                                      
         
   SET @b_Success  = 0
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_TaskBatchNo   = ISNULL(@c_TaskBatchNo,'')
      
   IF @c_TaskBatchNo = '' 
   BEGIN
      SELECT TOP 1 @c_Facility = o.Facility
      FROM dbo.PackHeader AS ph WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON ph.Orderkey = o.OrderKey
      WHERE ph.PickSlipNo = @c_PickSlipNo
      AND ph.OrderKey <> ''
      
      IF @c_Facility = ''
      BEGIN
         SELECT TOP 1 @c_Facility = lp.Facility
         FROM dbo.PackHeader AS ph WITH (NOLOCK)
         JOIN dbo.LoadPlan AS lp WITH (NOLOCK) ON ph.Loadkey = lp.Loadkey
         WHERE ph.PickSlipNo = @c_PickSlipNo
         AND ph.OrderKey = ''
      END
   END
   ELSE
   BEGIN
      SELECT TOP 1 @c_Facility = o.Facility
      FROM dbo.PackTask AS pt WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON pt.Orderkey = o.OrderKey
      WHERE pt.TaskBatchNo = @c_TaskBatchNo
   END
   
   SELECT @c_PackByLottable = fgr.Authority
         ,@c_PackByLottable_Opt05 = fgr.Option5
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PackByLottable') AS fgr
   
   SET @c_PrePackLACheck_SP = ''
   SELECT @c_PrePackLACheck_SP = dbo.fnc_GetParamValueFromString('@c_PackLAPreCheck_SP', @c_PackByLottable_Opt05, @c_PrePackLACheck_SP) 

   IF @c_PackByLottable = '0'
   BEGIN
       GOTO QUIT_SP
   END
      
   IF @c_PrePackLACheck_SP =''
   BEGIN
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects AS s WHERE id = OBJECT_ID(@c_PrePackLACheck_SP) AND type = 'P')
   BEGIN
       GOTO QUIT_SP
   END

   SET @c_SQL = N' EXEC ' + @c_PrePackLACheck_SP
              +  ' @c_PickSlipNo  = @c_PickSlipNo '
              + ', @c_Storerkey   = @c_Storerkey  '
              + ', @c_Sku         = @c_Sku        '
              + ', @c_TaskBatchNo = @c_TaskBatchNo' 
              + ', @b_Success     = @b_Success  OUTPUT' 
              + ', @n_Err         = @n_Err      OUTPUT'
              + ', @c_ErrMsg      = @c_ErrMsg   OUTPUT'
              
   SET @c_SQLParms = ' @c_PickSlipNo   NVARCHAR(10)'
                   +', @c_Storerkey    NVARCHAR(15)'
                   +', @c_Sku          NVARCHAR(20)'
                   +', @c_TaskBatchNo  NVARCHAR(10)' 
                   +', @b_Success      INT            OUTPUT'
                   +', @n_Err          INT            OUTPUT'
                   +', @c_ErrMsg       NVARCHAR(255)  OUTPUT' 
                      
    EXEC sp_executesql @c_SQL 
                     , @c_SQLParms
                     , @c_PickSlipNo  
                     , @c_Storerkey  
                     , @c_Sku        
                     , @c_TaskBatchNo
                     , @b_Success   OUTPUT
                     , @n_Err       OUTPUT
                     , @c_ErrMsg    OUTPUT

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackLAPreCheck_Wrapper'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO