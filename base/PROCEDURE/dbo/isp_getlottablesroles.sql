SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetLottablesRoles                                   */
/* Creation Date: 14-OCT-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Fixed Heavy Query Store Usage                               */
/*        : Call SP from PB instead of select using not bind parm       */
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
CREATE PROC [dbo].[isp_GetLottablesRoles]
           @c_ListName  NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)                   
         , @c_Sku                NVARCHAR(20)   
         , @c_Source             NVARCHAR(30)   = ''      
         , @c_SPName             NVARCHAR(60)   OUTPUT       
         , @c_LottableLabel      NVARCHAR(20)   OUTPUT
         , @c_UDF01              NVARCHAR(60)   OUTPUT 
         , @b_Success            NVARCHAR(60)   OUTPUT  --1: Get Using SP, 2: Get Using PB                      
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_SQL             NVARCHAR(4000) = ''
         , @c_SQLParms        NVARCHAR(1000) = ''


   SET @b_Success = 1

   SET @c_SQL = N'SELECT TOP 1  @c_SPName = ISNULL(CL.Long, '''')'
              +', @c_LottableLabel = ' + CASE WHEN @c_ListName = 'LOTTABLE01' THEN 'SKU.Lottable01Label'
                                              WHEN @c_ListName = 'LOTTABLE02' THEN 'SKU.Lottable02Label'
                                              WHEN @c_ListName = 'LOTTABLE03' THEN 'SKU.Lottable03Label'
                                              WHEN @c_ListName = 'LOTTABLE04' THEN 'SKU.Lottable04Label'
                                              WHEN @c_ListName = 'LOTTABLE05' THEN 'SKU.Lottable05Label'
                                              WHEN @c_ListName = 'LOTTABLE06' THEN 'SKU.Lottable06Label'
                                              WHEN @c_ListName = 'LOTTABLE07' THEN 'SKU.Lottable07Label'
                                              WHEN @c_ListName = 'LOTTABLE08' THEN 'SKU.Lottable08Label'
                                              WHEN @c_ListName = 'LOTTABLE09' THEN 'SKU.Lottable09Label'
                                              WHEN @c_ListName = 'LOTTABLE10' THEN 'SKU.Lottable10Label'
                                              WHEN @c_ListName = 'LOTTABLE11' THEN 'SKU.Lottable11Label'
                                              WHEN @c_ListName = 'LOTTABLE12' THEN 'SKU.Lottable12Label'
                                              WHEN @c_ListName = 'LOTTABLE13' THEN 'SKU.Lottable13Label'
                                              WHEN @c_ListName = 'LOTTABLE14' THEN 'SKU.Lottable14Label'
                                              WHEN @c_ListName = 'LOTTABLE15' THEN 'SKU.Lottable15Label'
                                              END
              +', @c_UDF01 = ISNULL(CL.UDF01, '''')'
              +' FROM CODELKUP CL WITH (NOLOCK)'
              +' JOIN SKU WITH (NOLOCK) ON CL.CODE = ' + 
                                         CASE WHEN @c_ListName = 'LOTTABLE01' THEN 'SKU.Lottable01Label'
                                              WHEN @c_ListName = 'LOTTABLE02' THEN 'SKU.Lottable02Label'
                                              WHEN @c_ListName = 'LOTTABLE03' THEN 'SKU.Lottable03Label'
                                              WHEN @c_ListName = 'LOTTABLE04' THEN 'SKU.Lottable04Label'
                                              WHEN @c_ListName = 'LOTTABLE05' THEN 'SKU.Lottable05Label'
                                              WHEN @c_ListName = 'LOTTABLE06' THEN 'SKU.Lottable06Label'
                                              WHEN @c_ListName = 'LOTTABLE07' THEN 'SKU.Lottable07Label'
                                              WHEN @c_ListName = 'LOTTABLE08' THEN 'SKU.Lottable08Label'
                                              WHEN @c_ListName = 'LOTTABLE09' THEN 'SKU.Lottable09Label'
                                              WHEN @c_ListName = 'LOTTABLE10' THEN 'SKU.Lottable10Label'
                                              WHEN @c_ListName = 'LOTTABLE11' THEN 'SKU.Lottable11Label'
                                              WHEN @c_ListName = 'LOTTABLE12' THEN 'SKU.Lottable12Label'
                                              WHEN @c_ListName = 'LOTTABLE13' THEN 'SKU.Lottable13Label'
                                              WHEN @c_ListName = 'LOTTABLE14' THEN 'SKU.Lottable14Label'
                                              WHEN @c_ListName = 'LOTTABLE15' THEN 'SKU.Lottable15Label'
                                              END
              +' WHERE CL.LISTNAME = @c_ListName'
              +   CASE WHEN @c_Source Like '%ITEMCHANGED' THEN ' '
                       ELSE ' AND CL.SHORT IN (''PRE'', ''BOTH'') ' 
                       END
              +' AND SKU.StorerKey = @c_StorerKey'
              +' AND SKU.Sku = @c_SKU'
              +' AND (CL.Storerkey = @c_StorerKey OR CL.Storerkey IS NULL OR CL.Storerkey = '''')'
              +' ORDER BY CL.Storerkey DESC'

      SET @c_SQLParms = N'@c_ListName        NVARCHAR(10)'
                      + ',@c_StorerKey       NVARCHAR(15)'
                      + ',@c_Sku             NVARCHAR(20)'
                      + ',@c_SPName          NVARCHAR(60)   OUTPUT'
                      + ',@c_LottableLabel   NVARCHAR(30)   OUTPUT'
                      + ',@c_UDF01           NVARCHAR(30)   OUTPUT'
                      
      EXEC sp_ExecuteSQL   @c_SQL  
                        ,  @c_SQLParms  
                        ,  @c_ListName     
                        ,  @c_StorerKey    
                        ,  @c_Sku          
                        ,  @c_SPName         OUTPUT       
                        ,  @c_LottableLabel  OUTPUT
                        ,  @c_UDF01          OUTPUT                                        
  
QUIT_SP:

END -- procedure

GO