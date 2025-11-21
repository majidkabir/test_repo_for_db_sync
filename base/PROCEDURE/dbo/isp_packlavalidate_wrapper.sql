SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackLAValidate_Wrapper                              */
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
CREATE PROC [dbo].[isp_PackLAValidate_Wrapper]
     @c_PickSlipNo   NVARCHAR(10)
   , @c_Storerkey    NVARCHAR(15) 
   , @c_Sku          NVARCHAR(20)  
   , @c_TaskBatchNo  NVARCHAR(10)   = '' 
   , @c_DropID       NVARCHAR(20)   = ''  
   , @c_PackByLA01   NVARCHAR(30)  
   , @c_PackByLA02   NVARCHAR(30)   = ''   
   , @c_PackByLA03   NVARCHAR(30)   = ''  
   , @c_PackByLA04   NVARCHAR(30)   = ''   
   , @c_PackByLA05   NVARCHAR(30)   = ''   
   , @c_SourceCol    NVARCHAR(20)   = ''                
   , @c_NextCol      NVARCHAR(20)   = ''  OUTPUT   
   , @c_Orderkey     NVARCHAR(10)   = ''  OUTPUT         
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
         , @c_PackByLottable_Opt1   NVARCHAR(30) = '' 
         , @c_PackByLottable_Opt05  NVARCHAR(500)= ''         
         , @c_PackLAValidate_SP     NVARCHAR(30) = ''
                  
         , @c_PackByLACondition     NVARCHAR(250)= ''
                           
         , @c_SQL                   NVARCHAR(1000) = ''
         , @c_SQLParms              NVARCHAR(1000) = ''  
                                                      
   DECLARE @t_LAEntry   TABLE
   (  RowRef      INT   IDENTITY(1,1) PRIMARY KEY
   ,  PackByLA    NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  PackByLASeq NVARCHAR(20)  NOT NULL DEFAULT('')
   )   
         
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Orderkey      = ISNULL(@c_Orderkey,'')
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
         ,@c_PackByLottable_Opt1 = fgr.Option1 
         ,@c_PackByLottable_Opt05 = fgr.Option5
   FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PackByLottable') AS fgr
   
   SET @c_PackLAValidate_SP = ''
   SELECT @c_PackLAValidate_SP = dbo.fnc_GetParamValueFromString('@c_PackLAValidate_SP', @c_PackByLottable_Opt05, @c_PackLAValidate_SP) 

   IF @c_PackByLottable = '0'
   BEGIN
       GOTO QUIT_SP
   END
      
   IF @c_PackLAValidate_SP =''
   BEGIN
       GOTO QUIT_SP
   END
   
   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects AS s WHERE id = OBJECT_ID(@c_PackLAValidate_SP) AND type = 'P')
   BEGIN
       GOTO QUIT_SP
   END

   SET @c_SQL = N' EXEC ' + @c_PackLAValidate_SP
              +  ' @c_PickSlipNo  = @c_PickSlipNo '
              + ', @c_Storerkey   = @c_Storerkey  '
              + ', @c_Sku         = @c_Sku        '
              + ', @c_TaskBatchNo = @c_TaskBatchNo'   
              + ', @c_DropID      = @c_DropID'                
              + ', @c_PackByLA01  = @c_PackByLA01 '
              + ', @c_PackByLA02  = @c_PackByLA02 '   
              + ', @c_PackByLA03  = @c_PackByLA03 '  
              + ', @c_PackByLA04  = @c_PackByLA04 '   
              + ', @c_PackByLA05  = @c_PackByLA05 '   
              + ', @c_SourceCol   = @c_SourceCol  '                
              + ', @c_NextCol     = @c_NextCol  OUTPUT'    
              + ', @c_Orderkey    = @c_Orderkey OUTPUT'         
              + ', @b_Success     = @b_Success  OUTPUT'
              + ', @n_Err         = @n_Err      OUTPUT'
              + ', @c_ErrMsg      = @c_ErrMsg   OUTPUT'
              
   SET @c_SQLParms = ' @c_PickSlipNo   NVARCHAR(10)'
                   +', @c_Storerkey    NVARCHAR(15)'
                   +', @c_Sku          NVARCHAR(20)'
                   +', @c_TaskBatchNo  NVARCHAR(10)' 
                   +', @c_DropID       NVARCHAR(20)'                     
                   +', @c_PackByLA01   NVARCHAR(30)'
                   +', @c_PackByLA02   NVARCHAR(30)'   
                   +', @c_PackByLA03   NVARCHAR(30)'  
                   +', @c_PackByLA04   NVARCHAR(30)'   
                   +', @c_PackByLA05   NVARCHAR(30)'   
                   +', @c_SourceCol    NVARCHAR(20)'                
                   +', @c_NextCol      NVARCHAR(20)   OUTPUT'        
                   +', @c_Orderkey     NVARCHAR(10)   OUTPUT'         
                   +', @b_Success      INT            OUTPUT'
                   +', @n_Err          INT            OUTPUT'
                   +', @c_ErrMsg       NVARCHAR(255)  OUTPUT' 
                      
    EXEC sp_executesql @c_SQL 
                     , @c_SQLParms
                     , @c_PickSlipNo  
                     , @c_Storerkey  
                     , @c_Sku        
                     , @c_TaskBatchNo
                     , @c_DropID 
                     , @c_PackByLA01 
                     , @c_PackByLA02 
                     , @c_PackByLA03 
                     , @c_PackByLA04 
                     , @c_PackByLA05 
                     , @c_SourceCol               
                     , @c_NextCol   OUTPUT 
                     , @c_Orderkey  OUTPUT        
                     , @b_Success   OUTPUT
                     , @n_Err       OUTPUT
                     , @c_ErrMsg    OUTPUT

   IF @b_Success = 0 
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END       
   
   IF @c_PackByLottable_Opt1 <> '' AND @c_NextCol = ''
   BEGIN
      INSERT INTO @t_LAEntry ( PackByLA )
      SELECT 'Lottable' + ss.value
      FROM STRING_SPLIT(@c_PackByLottable_Opt1, ',') AS ss
      
      UPDATE @t_LAEntry SET PackByLASeq = 'PackByLA0' + CONVERT(CHAR(1),RowRef )
      
      SELECT TOP 1 @c_NextCol = tle.PackByLASeq
      FROM @t_LAEntry AS tle 
      WHERE tle.PackByLASeq > @c_SourceCol
      ORDER BY tle.RowRef 
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackLAValidate_Wrapper'
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