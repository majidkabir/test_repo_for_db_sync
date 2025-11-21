SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_BuildPreWaveCond                                */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3672 - [CN] LOREAL_New Tab for order analysis          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.1                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-08-05  Wan      1.0   Created & DevOps Combine Script           */
/* 2022-09-20  Wan01    1.1   LFWM-3763 - SCE  LOREAL PROD  Cannot build*/ 
/*                            wave. Fix Truncated value                 */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_BuildPreWaveCond]                                                                                                                       
      @c_BuildParmKey      NVARCHAR(10)                                                                                                                    
   ,  @c_SQLCondPreWave    NVARCHAR(2000) = '' OUTPUT                  
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
   
   DECLARE @n_Continue                 INT            = 1
         , @n_StartTCnt                INT            = @@TRANCOUNT
         
         , @n_RowID                    INT            = 0
   
         , @n_Cnt                      INT            = 0
         , @c_FieldName                NVARCHAR(100)  = ''
         , @c_FieldName01              NVARCHAR(100)  = ''         
         , @c_FieldName02              NVARCHAR(100)  = ''  
         , @c_FieldName03              NVARCHAR(100)  = '' 
         , @c_FieldName04              NVARCHAR(100)  = ''  
         , @c_FieldName05              NVARCHAR(100)  = ''  
         , @c_Columns01                NVARCHAR(600)  = ''              
         , @c_Columns02                NVARCHAR(600)  = ''              
         , @c_Columns03                NVARCHAR(600)  = ''              
         , @c_Columns04                NVARCHAR(600)  = ''              
         , @c_Columns05                NVARCHAR(600)  = ''                        
         , @c_Column01                 NVARCHAR(100)  = ''
         , @c_Column02                 NVARCHAR(100)  = '' 
         , @c_Column03                 NVARCHAR(100)  = ''  
         , @c_Column04                 NVARCHAR(100)  = '' 
         , @c_Column05                 NVARCHAR(100)  = '' 
         
         , @c_BuildParmPreWaveLineNo   NVARCHAR(5)    = ''

   SET @c_SQLCondPreWave = ''
   SET @n_Cnt = 0
   SET @c_BuildParmPreWaveLineNo = ''

   WHILE @n_Cnt < 5
   BEGIN
      SELECT TOP 1 
               @c_FieldName = b.FieldName
            ,  @c_BuildParmPreWaveLineNo = b.BuildParmPreWaveLineNo
      FROM dbo.BUILDPARMPREWAVE AS b WITH (NOLOCK)
      WHERE b.BuildParmKey = @c_BuildParmKey
      AND b.BuildParmPreWaveLineNo > @c_BuildParmPreWaveLineNo
      AND b.FieldName <> ''
      ORDER BY b.BuildParmPreWaveLineNo
          
      IF @@ROWCOUNT = 0 
      BEGIN
         BREAK
      END
         
      SET @n_Cnt = @n_Cnt + 1
      IF @n_Cnt = 1 SET @c_FieldName01 = @c_FieldName
      IF @n_Cnt = 2 SET @c_FieldName02 = @c_FieldName
      IF @n_Cnt = 3 SET @c_FieldName03 = @c_FieldName
      IF @n_Cnt = 4 SET @c_FieldName04 = @c_FieldName
      IF @n_Cnt = 5 SET @c_FieldName05 = @c_FieldName
   END
      
   IF @n_Cnt > 0
   BEGIN
      --(Wan01) - START
      SET @c_SQLCondPreWave = @c_SQLCondPreWave 
                        + ' AND EXISTS (SELECT 1 FROM dbo.BUILDPREWAVE AS b WITH (NOLOCK)'  
                        + ' WHERE b.BuildParmKey = @c_BuildParmKey' 
                        + ' AND b.[Status] = ''1'''
                        + CASE WHEN @c_FieldName01 <> '' THEN ' AND ' + @c_FieldName01 + '= b.Column01' END
                        + CASE WHEN @c_FieldName02 <> '' THEN ' AND ' + @c_FieldName02 + '= b.Column02' END
                        + CASE WHEN @c_FieldName03 <> '' THEN ' AND ' + @c_FieldName03 + '= b.Column03' END
                        + CASE WHEN @c_FieldName04 <> '' THEN ' AND ' + @c_FieldName04 + '= b.Column04' END
                        + CASE WHEN @c_FieldName05 <> '' THEN ' AND ' + @c_FieldName05 + '= b.Column05' END 
                        + ')'   
      --SET @n_RowID = 0
      --WHILE 1 = 1
      --BEGIN 
      --   SELECT TOP 1
      --          @c_Column01 = ISNULL(b.Column01,'') 
      --         ,@c_Column02 = ISNULL(b.Column02,'') 
      --         ,@c_Column03 = ISNULL(b.Column03,'') 
      --         ,@c_Column04 = ISNULL(b.Column04,'') 
      --         ,@c_Column05 = ISNULL(b.Column05,'') 
      --         ,@n_RowID    = b.RowID
      --   FROM dbo.BUILDPREWAVE AS b WITH (NOLOCK) 
      --   WHERE b.BuildParmKey = @c_BuildParmKey
      --   AND b.RowID > @n_RowID
      --   AND b.[Status] = '1'
            
      --   IF @@ROWCOUNT = 0
      --   BEGIN
      --      BREAK
      --   END
            
      --   IF @c_FieldName01 <> ''
      --   BEGIN
      --      IF @c_Columns01 <> '' SET @c_Columns01 = @c_Columns01 + ','
      --      SET @c_Columns01 = @c_Columns01 + 'N''' + @c_Column01 + ''''
      --   END
            
      --   IF @c_FieldName02 <> ''
      --   BEGIN
      --      IF @c_Columns02 <> '' SET @c_Columns02 = @c_Columns02 + ','
      --      SET @c_Columns02 = @c_Columns02 + 'N''' + @c_Column02 + ''''
      --   END
            
      --   IF @c_FieldName03 <> ''
      --   BEGIN
      --      IF @c_Columns03 <> '' SET @c_Columns03 = @c_Columns03 + ','
      --      SET @c_Columns03 = @c_Columns03 + 'N''' + @c_Column03 + ''''
      --   END
            
      --   IF @c_FieldName04 <> ''
      --   BEGIN
      --      IF @c_Columns04 <> '' SET @c_Columns04 = @c_Columns04 + ','
      --      SET @c_Columns04 = @c_Columns04 + 'N''' + @c_Column04 + ''''
      --   END 
             
      --   IF @c_FieldName05 <> ''
      --   BEGIN
      --      IF @c_Columns05 <> '' SET @c_Columns05 = @c_Columns05 + ','
      --      SET @c_Columns05 = @c_Columns05 + 'N''' + @c_Column05 + ''''
      --   END                      
      --END
   
      --IF @c_FieldName01 <> '' AND @c_Columns01 <> ''
      --   SET @c_SQLCondPreWave = @c_SQLCondPreWave + 'AND ' + @c_FieldName01 + ' IN ( ' + @c_Columns01 + ')'
      --IF @c_FieldName02 <> '' AND @c_Columns02 <> ''
      --   SET @c_SQLCondPreWave = @c_SQLCondPreWave + 'AND ' + @c_FieldName02 + ' IN ( ' + @c_Columns02 + ')'
      --IF @c_FieldName03 <> '' AND @c_Columns03 <> ''
      --   SET @c_SQLCondPreWave = @c_SQLCondPreWave + 'AND ' + @c_FieldName03 + ' IN ( ' + @c_Columns03 + ')'
      --IF @c_FieldName04 <> '' AND @c_Columns04 <> ''
      --   SET @c_SQLCondPreWave = @c_SQLCondPreWave + 'AND ' + @c_FieldName04 + ' IN ( ' + @c_Columns04 + ')'
      --IF @c_FieldName05 <> '' AND @c_Columns05 <> ''
      --   SET @c_SQLCondPreWave = @c_SQLCondPreWave + 'AND ' + @c_FieldName05 + ' IN ( ' + @c_Columns05 + ')'
      --(Wan01) - END
   END
END

GO