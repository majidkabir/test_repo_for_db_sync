SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetQueryResult                                      */
/* Creation Date: 15-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: Many Literal Values Fixed; Use SP to Get Value from PB      */
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
CREATE PROC [dbo].[isp_GetQueryResult]
           @c_SQL       NVARCHAR(4000)
         , @c_Parm1     NVARCHAR(30)   = ''
         , @c_Parm2     NVARCHAR(30)   = ''
         , @c_Parm3     NVARCHAR(30)   = ''
         , @c_Parm4     NVARCHAR(30)   = ''
         , @c_Parm5     NVARCHAR(30)   = ''
         , @c_Parm6     NVARCHAR(30)   = ''
         , @c_Parm7     NVARCHAR(30)   = ''
         , @c_Parm8     NVARCHAR(30)   = ''
         , @c_Parm9     NVARCHAR(30)   = ''
         , @c_Parm10    NVARCHAR(30)   = ''
         , @n_Parm1     BIGINT         = 0
         , @n_Parm2     INT            = 0
         , @dt_Parm1    DATETIME       = NULL
         , @dt_Parm2    DATETIME       = NULL
         , @dt_Parm3    DATETIME       = NULL
         , @dt_Parm4    DATETIME       = NULL
         , @dt_Parm5    DATETIME       = NULL
         , @c_Output1   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output2   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output3   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output4   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output5   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output6   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output7   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output8   NVARCHAR(30)   = ''     OUTPUT 
         , @c_Output9   NVARCHAR(255)  = ''     OUTPUT 
         , @c_Output10  NVARCHAR(255)  = ''     OUTPUT 
         , @n_Output1   INT            = 0      OUTPUT
         , @n_Output2   INT            = 0      OUTPUT
         , @n_Output3   FLOAT          = 0.00   OUTPUT
         , @n_Output4   FLOAT          = 0.00   OUTPUT
         , @n_Output5   FLOAT          = 0.00   OUTPUT
         , @dt_Output1  DATETIME       = NULL   OUTPUT
         , @dt_Output2  DATETIME       = NULL   OUTPUT
         , @dt_Output3  DATETIME       = NULL   OUTPUT
         , @dt_Output4  DATETIME       = NULL   OUTPUT
         , @dt_Output5  DATETIME       = NULL   OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_SQLParms        NVARCHAR(4000) = ''

   SET @n_StartTCnt = @@TRANCOUNT

   IF ISNULL(@c_SQL,'') = ''
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_SQL = N'' + @c_SQL

   SET @c_SQLParms = N' @c_Parm1     NVARCHAR(30)'
                   + ', @c_Parm2     NVARCHAR(30)'
                   + ', @c_Parm3     NVARCHAR(30)'
                   + ', @c_Parm4     NVARCHAR(30)'
                   + ', @c_Parm5     NVARCHAR(30)'
                   + ', @c_Parm6     NVARCHAR(30)'
                   + ', @c_Parm7     NVARCHAR(30)'
                   + ', @c_Parm8     NVARCHAR(30)'
                   + ', @c_Parm9     NVARCHAR(30)'
                   + ', @c_Parm10    NVARCHAR(30)'
                   + ', @n_Parm1     INT'         
                   + ', @n_Parm2     INT'         
                   + ', @dt_Parm1    DATETIME'    
                   + ', @dt_Parm2    DATETIME'    
                   + ', @dt_Parm3    DATETIME'    
                   + ', @dt_Parm4    DATETIME'    
                   + ', @dt_Parm5    DATETIME'    
                   + ', @c_Output1   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output2   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output3   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output4   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output5   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output6   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output7   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output8   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output9   NVARCHAR(30)   OUTPUT' 
                   + ', @c_Output10  NVARCHAR(255)  OUTPUT' 
                   + ', @n_Output1   INT            OUTPUT'
                   + ', @n_Output2   INT            OUTPUT'
                   + ', @n_Output3   FLOAT          OUTPUT'
                   + ', @n_Output4   FLOAT          OUTPUT'
                   + ', @n_Output5   FLOAT          OUTPUT'
                   + ', @dt_Output1  DATETIME       OUTPUT'
                   + ', @dt_Output2  DATETIME       OUTPUT'
                   + ', @dt_Output3  DATETIME       OUTPUT'
                   + ', @dt_Output4  DATETIME       OUTPUT'
                   + ', @dt_Output5  DATETIME       OUTPUT'
 
   EXEC sp_ExecuteSQL @c_SQL
                  ,  @c_SQLParms
                  ,  @c_Parm1    
                  ,  @c_Parm2   
                  ,  @c_Parm3   
                  ,  @c_Parm4   
                  ,  @c_Parm5   
                  ,  @c_Parm6   
                  ,  @c_Parm7   
                  ,  @c_Parm8   
                  ,  @c_Parm9   
                  ,  @c_Parm10  
                  ,  @n_Parm1  
                  ,  @n_Parm2  
                  ,  @dt_Parm1 
                  ,  @dt_Parm2 
                  ,  @dt_Parm3 
                  ,  @dt_Parm4 
                  ,  @dt_Parm5 
                  ,  @c_Output1  OUTPUT 
                  ,  @c_Output2  OUTPUT 
                  ,  @c_Output3  OUTPUT 
                  ,  @c_Output4  OUTPUT 
                  ,  @c_Output5  OUTPUT 
                  ,  @c_Output6  OUTPUT 
                  ,  @c_Output7  OUTPUT 
                  ,  @c_Output8  OUTPUT 
                  ,  @c_Output9  OUTPUT 
                  ,  @c_Output10 OUTPUT
                  ,  @n_Output1  OUTPUT
                  ,  @n_Output2  OUTPUT
                  ,  @n_Output3  OUTPUT
                  ,  @n_Output4  OUTPUT
                  ,  @n_Output5  OUTPUT
                  ,  @dt_Output1 OUTPUT
                  ,  @dt_Output2 OUTPUT
                  ,  @dt_Output3 OUTPUT
                  ,  @dt_Output4 OUTPUT
                  ,  @dt_Output5 OUTPUT   
                  
QUIT_SP:

END -- procedure

GO