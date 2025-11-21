SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_EGetPackByLA                                        */
/* Creation Date: 2021-11-23                                            */
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
/* 2021-11-23  Wan      1.0   Created.                                  */
/* 2021-11-23  Wan      1.0   DevOps Combine Script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_EGetPackByLA]
     @c_PickSlipNo      NVARCHAR(10)
   , @c_Storerkey       NVARCHAR(15) 
   , @c_Sku             NVARCHAR(20)
   , @c_TaskBatchNo     NVARCHAR(10) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt             INT =  @@TRANCOUNT
         , @n_Continue              INT = 1
         
         , @c_Facility              NVARCHAR(5)  = ''
         , @c_PackByLottable_Opt1   NVARCHAR(60) = ''
         , @c_PackByLottable_Opt3   NVARCHAR(60) = ''
         
         , @c_TableColumns          NVARCHAR(250)= ''
         
         , @c_SQL                   NVARCHAR(500)= ''
         , @c_SQLParms              NVARCHAR(500)= '' 
         
         , @c_PackLALabel01         NVARCHAR(20) = '' 
         , @c_PackLALabel02         NVARCHAR(20) = ''
         , @c_PackLALabel03         NVARCHAR(20) = ''
         , @c_PackLALabel04         NVARCHAR(20) = ''
         , @c_PackLALabel05         NVARCHAR(20) = ''
         
         , @c_PackByLA01            NVARCHAR(30) = '' 
         , @c_PackByLA02            NVARCHAR(30) = ''
         , @c_PackByLA03            NVARCHAR(30) = ''
         , @c_PackByLA04            NVARCHAR(30) = ''
         , @c_PackByLA05            NVARCHAR(30) = ''
         , @c_ErrMsg                NVARCHAR(250)= ''

   DECLARE @t_LAField   TABLE
         (  RowRef      INT   IDENTITY(1,1) PRIMARY KEY
         ,  PackByLA    NVARCHAR(20)  NOT NULL DEFAULT('')
         )
                    
   SELECT TOP 1 @c_Facility = o.Facility
   FROM dbo.PackTask AS pt WITH (NOLOCK)
   JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.OrderKey = pt.Orderkey
   WHERE pt.TaskBatchNo = @c_TaskbatchNo
   ORDER BY pt.RowRef 

   SELECT @c_PackByLottable_Opt1 = fgr.Option1 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PackByLottable') AS fgr
      
   IF @c_PackByLottable_Opt1 <> ''
   BEGIN
      INSERT INTO @t_LAfield ( PackByLA ) 
      SELECT 'Lottable' + ss.value + 'label'
      FROM STRING_SPLIT(@c_PackByLottable_Opt1, ',') AS ss
      
      
      SET @c_TableColumns = @c_TableColumns  
                             + RTRIM(ISNULL(CONVERT(VARCHAR(250),  
                                            (  SELECT '@c_PackLALabel0' + CONVERT(CHAR(1),tla.RowRef) + '=' + RTRIM(tla.PackByLA) + ',' 
                                               FROM @t_LAfield AS tla
                                               ORDER BY tla.RowRef 
                                               FOR XML PATH(''), TYPE  
                                             )  
                                           )  
                                       ,'')  
                                    )  
      
      IF @c_TableColumns <> '' SET @c_TableColumns = LEFT(@c_TableColumns, LEN(@c_TableColumns) - 1)
      
      SET @c_SQL = N'SELECT ' + @c_TableColumns
                 + ' FROM dbo.SKU AS s WITH (NOLOCK)'
                 + ' WHERE s.StorerKey = @c_Storerkey'
                 + ' AND s.Sku = @c_Sku'
      
      SET @c_SQLParms = N'@c_Storerkey       NVARCHAR(15)'
                      + ',@c_Sku             NVARCHAR(20)'
                      + ',@c_PackLALabel01   NVARCHAR(60)   OUTPUT'      
                      + ',@c_PackLALabel02   NVARCHAR(60)   OUTPUT'   
                      + ',@c_PackLALabel03   NVARCHAR(60)   OUTPUT'                    
                      + ',@c_PackLALabel04   NVARCHAR(60)   OUTPUT'  
                      + ',@c_PackLALabel05   NVARCHAR(60)   OUTPUT'   
                      
      EXEC sp_ExecuteSQL @c_SQL
                        ,@c_SQLParms
                        ,@c_Storerkey     
                        ,@c_Sku           
                        ,@c_PackLALabel01 OUTPUT 
                        ,@c_PackLALabel02 OUTPUT 
                        ,@c_PackLALabel03 OUTPUT 
                        ,@c_PackLALabel04 OUTPUT 
                        ,@c_PackLALabel05 OUTPUT 
                      
   END
QUIT_SP:
   SELECT  'PickSlipNo'   = @c_PickSlipNo
         , 'Storerkey'    = @c_Storerkey
         , 'Sku'          = @c_Sku
         , 'PackLALabel01'= @c_PackLALabel01 + CASE WHEN  @c_PackLALabel01 = '' THEN '' ELSE ': ' END
         , 'PackLALabel02'= @c_PackLALabel02 + CASE WHEN  @c_PackLALabel02 = '' THEN '' ELSE ': ' END
         , 'PackLALabel03'= @c_PackLALabel03 + CASE WHEN  @c_PackLALabel03 = '' THEN '' ELSE ': ' END
         , 'PackLALabel04'= @c_PackLALabel04 + CASE WHEN  @c_PackLALabel04 = '' THEN '' ELSE ': ' END
         , 'PackLALabel05'= @c_PackLALabel05 + CASE WHEN  @c_PackLALabel05 = '' THEN '' ELSE ': ' END 
         , 'PackByLA01'   = @c_PackByLA01
         , 'PackByLA02'   = @c_PackByLA02
         , 'PackByLA03'   = @c_PackByLA03
         , 'PackByLA04'   = @c_PackByLA04
         , 'PackByLA05'   = @c_PackByLA05
         , 'ErrMsg'       = @c_ErrMsg
END -- procedure

GO