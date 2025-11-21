SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_PackLAValidate01                                    */
/* Creation Date: 2021-12-03                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-18322 - [CN]DYSON_Ecompacking_X708_Function_CR          */
/*        :                                                             */
/* Called By: isp_PackLAValidate_Wrapper                                */
/*          : isp_PackLAValidateXX                                      */
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
CREATE PROC [dbo].[isp_PackLAValidate01]
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
         
         , @n_QtyPicked_LA          INT = 0
         , @n_Qty_LA                INT = 0

         , @c_Facility              NVARCHAR(5) = ''
         , @c_PackByLottable_Opt1   NVARCHAR(30) = '' 
         , @c_PackByLACondition     NVARCHAR(250)= ''
                  
         , @c_SQL                   NVARCHAR(500)= '' 
         , @c_SQLParms              NVARCHAR(500)= '' 
         
   DECLARE @t_LAField   TABLE
      (  RowRef      INT   IDENTITY(1,1) PRIMARY KEY
      ,  PackByLA    NVARCHAR(20)  NOT NULL DEFAULT('')
      )             


   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

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
    
    
   IF @c_Orderkey <> ''
   BEGIN
      SELECT @c_PackByLottable_Opt1 = fgr.Option1 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PackByLottable') AS fgr

      IF @c_PackByLottable_Opt1 <> ''
      BEGIN
         INSERT INTO @t_LAfield ( PackByLA ) 
         SELECT 'Lottable' + ss.value 
         FROM STRING_SPLIT(@c_PackByLottable_Opt1, ',') AS ss
      
         SET @c_PackByLACondition = @c_PackByLACondition  
                        + RTRIM(ISNULL(CONVERT(VARCHAR(250),  
                                       (  SELECT ' AND l.' + RTRIM(tla.PackByLA) + ' = @c_PackByLA0' + CONVERT(CHAR(1),tla.RowRef)
                                          FROM @t_LAfield AS tla
                                          ORDER BY tla.RowRef 
                                          FOR XML PATH(''), TYPE  
                                       )  
                                       )  
                                 ,'')  
                              )  
      END

      SET @c_SQL = N'SELECT @n_QtyPicked_LA  = SUM(PD.Qty)'
                 + ' FROM dbo.ORDERS o WITH (NOLOCK)'
                 + ' JOIN dbo.PICKDETAIL pd WITH (NOLOCK) ON o.Orderkey = pd.Orderkey '
                 + ' JOIN dbo.LOTATTRIBUTE AS l WITH (NOLOCK) ON pd.Lot = l.Lot'    
                 + ' WHERE o.Orderkey = @c_Orderkey'
                 + ' AND pd.Storerkey = @c_Storerkey'
                 + ' AND pd.Sku = @c_Sku'
                 + ' AND pd.[Status] <= ''5''' 
                 + @c_PackByLACondition
            
      SET @c_SQLParms = N'@c_Orderkey     NVARCHAR(10)'
                      + ',@c_Storerkey    NVARCHAR(15)'
                      + ',@c_Sku          NVARCHAR(20)'
                      + ',@c_PackByLA01   NVARCHAR(60)'      
                      + ',@c_PackByLA02   NVARCHAR(60)'   
                      + ',@c_PackByLA03   NVARCHAR(60)'                    
                      + ',@c_PackByLA04   NVARCHAR(60)'  
                      + ',@c_PackByLA05   NVARCHAR(60)' 
                      + ',@n_QtyPicked_LA INT         OUTPUT'  
                      
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_Orderkey
                        ,@c_Storerkey     
                        ,@c_Sku           
                        ,@c_PackByLA01
                        ,@c_PackByLA02
                        ,@c_PackByLA03
                        ,@c_PackByLA04
                        ,@c_PackByLA05
                        ,@n_QtyPicked_LA  OUTPUT  

      SET @n_QtyPicked_LA = ISNULL(@n_QtyPicked_LA,0)
      
      IF @n_QtyPicked_LA = 0 
      BEGIN
         SET @n_Continue = 3
      END
 
      IF @n_Continue = 1
      BEGIN
         SELECT @n_Qty_LA = SUM(Qty)
         FROM dbo.PackDetail AS pd WITH (NOLOCK)
         WHERE pd.PickSlipNo = @c_PickSlipNo
         AND pd.StorerKey = @c_Storerkey
         AND pd.SKU = @c_Sku
         AND pd.LOTTABLEVALUE = @c_PackByLA01
         GROUP BY pd.PickSlipNo, pd.StorerKey, pd.SKU, pd.LOTTABLEVALUE
         
         IF @n_Qty_LA + 1 > @n_QtyPicked_LA     -- IF Current Scan Sku lottableValue qty + Pack Sku LottableValue qty > Picked lottable0value qty
         BEGIN
            SET @n_Continue = 3
         END
      END

      IF @n_Continue = 3
      BEGIN
         SET @n_Err = 69010
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Mismatch Lottable Value found. (isp_PackLAValidate01)'  
         GOTO QUIT_SP 
      END
   END
   
   IF @c_TaskBatchNo <> '' AND @c_Orderkey = ''
   BEGIN
      IF EXISTS (SELECT TOP 1 1 FROM dbo.PackTask AS pt WITH (NOLOCK) WHERE pt.TaskBatchNo = @c_TaskBatchNo AND pt.OrderMode LIKE 'S%')
      BEGIN
         EXEC dbo.isp_Ecom_GetPackTaskOrders_S
               @c_TaskBatchNo = @c_TaskBatchNo
             , @c_PickSlipNo  = @c_PickSlipNo
             , @c_Orderkey    = @c_Orderkey OUTPUT
             , @b_packcomfirm = 0
             , @c_DropID      = @c_DropID
             , @c_FindSku     = @c_Sku     
             , @c_PackByLA01  = @c_PackByLA01  
             , @c_PackByLA02  = @c_PackByLA02  
             , @c_PackByLA03  = @c_PackByLA03  
             , @c_PackByLA04  = @c_PackByLA04  
             , @c_PackByLA05  = @c_PackByLA05  
             
         IF @c_Orderkey = ''
         BEGIN 
            SET @n_Continue = 3
            SET @n_Err = 69020
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Mismatch Lottable Value found. (isp_PackLAValidate01)'  
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PackLAValidate01'
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