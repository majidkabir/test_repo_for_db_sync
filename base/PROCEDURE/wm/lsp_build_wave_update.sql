SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_Build_Wave_Update                               */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3672 - [CN] LOREAL_New Tab for order analysis          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-08-05  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_Build_Wave_Update]                                                                                                                       
      @n_BatchNo           BIGINT 
   ,  @b_Success           INT            = 1  OUTPUT  
   ,  @n_err               INT            = 0  OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT 
   ,  @b_debug             INT            = 0                                                                                                                              
AS                                                                                                                                                                         
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue        INT            = 1
         , @n_StartTCnt       INT            = @@TRANCOUNT
                                                                                                              
         , @c_Facility        NVARCHAR(5)    = ''                                                                                                                 
         , @c_StorerKey       NVARCHAR(15)   = ''
         , @c_BuildParmKey    NVARCHAR(10)   = ''
         , @c_BuildParmLineNo NVARCHAR(5)    = ''           
         , @c_FieldName       NVARCHAR(100)  = ''
         , @c_Operator        NVARCHAR(MAX)  = ''           
         , @c_BuildValue      NVARCHAR(MAX)  = ''   
         
         , @c_SQL             NVARCHAR(MAX)  = ''
         , @c_SQLParms        NVARCHAR(2000) = ''  
         , @c_SQLUpdateField  NVARCHAR(2000) = ''
         , @c_UpdateValue     NVARCHAR(255)  = ''                   
         
   SET @b_Success = 1
   SET @n_Err     = 0
   
   BEGIN TRY
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
   
      SELECT @c_BuildParmKey = b.BuildParmKey
            ,@c_Facility  = b.Facility
            ,@c_Storerkey = b.Storerkey
      FROM dbo.BUILDWAVELOG AS b WITH (NOLOCK)
      WHERE b.BatchNo = @n_BatchNo
  
      BEGIN TRAN
      SET @c_BuildParmLineNo = ''
      WHILE 1 = 1 AND @n_Continue = 1
      BEGIN
         SET @c_FieldName = ''
         SET @c_Operator = ''
         SET @c_BuildValue = ''
         SELECT TOP 1 @c_BuildParmLineNo = b.BuildParmLineNo
                     ,@c_FieldName = b.FieldName
                     ,@c_Operator  = b.Operator
                     ,@c_BuildValue= b.BuildValue
         FROM dbo.BUILDPARMDETAIL AS b WITH (NOLOCK)
         WHERE b.BuildParmKey = @c_BuildParmKey
         AND b.BuildParmLineNo > @c_BuildParmLineNo
         AND b.[Type] = 'Edit'
         ORDER BY b.BuildParmLineNo
      
         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END
         
         SET @c_UpdateValue = ''
         SET @c_SQLUpdateField = ''
      
         IF @c_Operator IN ( 'IN', '=' )
         BEGIN
            SET @c_SQLUpdateField = ', ' + @c_FieldName + '= @c_BuildValue'
            IF @c_BuildValue <> ''        --2022-08-23
            BEGIN
               SET @c_BuildValue = LTRIM(RTRIM(@c_BuildValue))
               IF LEFT(LTRIM(@c_BuildValue),1) = '''' AND RIGHT(RTRIM(@c_BuildValue),1) = ''''
               BEGIN
                  SET @c_BuildValue = REPLACE(LEFT(@c_BuildValue,1),'''','') + RIGHT(@c_BuildValue,LEN(@c_BuildValue)-1)
                  SET @c_BuildValue = LEFT(@c_BuildValue,LEN(@c_BuildValue)-1) + REPLACE(RIGHT(@c_BuildValue,1), '''','')
               END
               SET @c_BuildValue = LTRIM(RTRIM(@c_BuildValue))
            END
         END
      
         IF @c_Operator IN ( 'IN SQL' )
         BEGIN
            SET @c_SQLUpdateField = ', ' + @c_FieldName + '= (' + @c_BuildValue + ')'
         END

         IF @c_SQLUpdateField <> ''
         BEGIN
            SET @c_SQL = N'UPDATE WAVE SET WAVE.EditWho = SUSER_SNAME(), WAVE.EditDate = GETDATE(), WAVE.Trafficcop = NULL'
                       + @c_SQLUpdateField
                       + ' FROM dbo.BUILDWAVEDETAILLOG AS b WITH (NOLOCK)'  
                       + ' JOIN dbo.WAVE ON WAVE.Wavekey = b.Wavekey' 
                       + ' WHERE b.BatchNo = @n_BatchNo' 
            SET @c_SQLParms = N'@n_BatchNo      BIGINT'
                            + ',@c_BuildValue   NVARCHAR(4000)'
      
            EXEC sp_ExecuteSQL @c_SQL
                              ,@c_SQLParms
                              ,@n_BatchNo
                              ,@c_BuildValue
                              
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 560801
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(6), @n_Err) 
                             + ': UPDATE WAVE Fail. (lsp_Build_Wave_Update) ' 
               GOTO EXIT_SP              
            END                  
         END
      END  
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   
   EXIT_SP:
   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0 
      BEGIN
         ROLLBACK TRAN
      END
      SET @b_Success = 0
   END
   ELSE
   BEGIN 
      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
      SET @b_Success = 1
   END
   
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
END

GO