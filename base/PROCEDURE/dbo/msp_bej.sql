SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_BEJ                                                 */
/* Creation Date: 2024-10-08                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: SQL JOB                                                   */
/*          :                                                           */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-10-08  Wan      1.0   Created.                                  */
/************************************************************************/
CREATE   PROC msp_BEJ
   @c_jobname   NVARCHAR(30) = 'BEJ-STD-01'
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT            = @@TRANCOUNT
         , @n_Continue        INT            = 1
         , @c_ErrMsg          NVARCHAR(255)  = ''
 
         , @c_Code            NVARCHAR(30)   = ''
         , @c_Storerkey       NVARCHAR(15)   = ''
         , @c_Facility        NVARCHAR(30)   = ''
         , @c_StoredProc      NVARCHAR(100)  = ''
         , @c_OtherConfig     NVARCHAR(4000) = ''
         , @c_SQL             NVARCHAR(500)  = ''
         , @c_PName           NVARCHAR(30)   = '' 

         , @CUR_JOB           CURSOR
         , @CUR_PARMS         CURSOR

   IF OBJECT_ID('tempdb..#TMP_BEJCL','u') IS NOT NULL         
   BEGIN
      DROP TABLE #TMP_BEJCL;
   END
   --sp_help codelkup
   CREATE TABLE #TMP_BEJCL
   (  ListName    NVARCHAR(10)   NOT NULL    DEFAULT ('')
   ,  Code        NVARCHAR(30)   NOT NULL    DEFAULT ('')
   ,  Short       NVARCHAR(10)   NOT NULL    DEFAULT ('')
   ,  Long        NVARCHAR(250)  NOT NULL    DEFAULT ('')
   ,  UDF01       NVARCHAR(50)   NOT NULL    DEFAULT ('')
   ,  UDF02       NVARCHAR(50)   NOT NULL    DEFAULT ('')
   ,  UDF03       NVARCHAR(50)   NOT NULL    DEFAULT ('')
   ,  UDF04       NVARCHAR(50)   NOT NULL    DEFAULT ('')
   ,  UDF05       NVARCHAR(50)   NOT NULL    DEFAULT ('')
   ,  Storerkey   NVARCHAR(15)   NOT NULL    DEFAULT ('')
   ,  Code2       NVARCHAR(30)   NOT NULL    DEFAULT ('')
   ,  Notes       NVARCHAR(4000) NOT NULL    DEFAULT ('')
   ,  Notes2      NVARCHAR(4000) NOT NULL    DEFAULT ('')
   )
       
   INSERT INTO #TMP_BEJCL 
      (  ListName, Code, Storerkey, Code2
      ,  Short, Long, UDF01, UDF02, UDF03, UDF04, UDF05, Notes, Notes2)
   SELECT ListName, Code, Storerkey, Code2
         ,Short, Long
         ,UDF01 = IIF(ISNUMERIC(cl.UDF01)=0,'9',cl.UDF01) 
         ,UDF02
         ,UDF03 = IIF(ISNUMERIC(cl.UDF03)=0,60,cl.UDF03)
         ,UDF04 = CONVERT(NVARCHAR(25),IIF(ISDATE(cl.UDF04)=0,DATEADD(ss,-1*cl.UDF03,GETDATE()),cl.UDF04),121)
         ,UDF05
         ,Notes = ISNULL(cl.Notes,''), Notes2 = ISNULL(cl.Notes2,'')
   FROM   CODELKUP cl WITH (NOLOCK)
   WHERE  cl.ListName = 'BEJ'
   AND    cl.Code     = @c_Jobname
   AND    cl.SHORT    = 'Y'
   AND    cl.Long NOT IN ('', NULL)
      
   SET @CUR_JOB = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT cl.code 
         ,StoredProc = ISNULL(cl.Long,'')
         ,cl.Storerkey
         ,cl.code2
         ,cl.Notes
   FROM   #TMP_BEJCL cl
   WHERE  cl.ListName = 'BEJ'
   AND    cl.Code     = @c_Jobname
   AND    cl.SHORT    = 'Y'
   AND    DATEDIFF(ss, CONVERT(DATETIME, cl.UDF04), GETDATE()) >= cl.UDF03
   ORDER BY DATEDIFF(ss, CONVERT(DATETIME, cl.UDF04), GETDATE())
         ,  cl.UDF01                --Priority
         ,  cl.UDF02                --JobStep
         ,  cl.UDF03                --Occur Every in second. Min = 10s 
      
   OPEN @CUR_JOB
   
   FETCH NEXT FROM @CUR_JOB INTO @c_Code, @c_StoredProc
                              ,  @c_Storerkey, @c_Facility
                              ,  @c_OtherConfig                              
   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      IF NOT EXISTS (SELECT 1 FROM sys.objects (NOLOCK) 
                     WHERE Object_ID(@c_StoredProc) = object_id 
                     AND [Type] = 'P')
      BEGIN
         GOTO NEXT_JOB
      END

      BEGIN TRY
        SET @c_SQL = 'EXEC '  + @c_StoredProc

         SET @CUR_PARMS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT PARAMETER_NAME   
         FROM [INFORMATION_SCHEMA].[PARAMETERS]     
         WHERE SPECIFIC_NAME = @c_StoredProc     
         ORDER BY ORDINAL_POSITION    
    
         OPEN @CUR_PARMS    
         FETCH NEXT FROM @CUR_PARMS INTO @c_PName 
         WHILE @@FETCH_STATUS <> -1    
         BEGIN 
            IF @c_SQL <> 'EXEC ' + @c_StoredProc 
            BEGIN
               SET @c_SQL = @c_SQL + ','
            END


            SET @c_SQL = @c_SQL + ' '      
                       + CASE WHEN @c_PName IN ('@c_Facility', '@c_StorerKey', '@c_OtherConfig')   
                              THEN @c_PName + '=' + @c_PName    
                              END
            FETCH NEXT FROM @CUR_PARMS INTO @c_PName                              
         END
         CLOSE @CUR_PARMS
         DEALLOCATE @CUR_PARMS

         EXEC sp_ExecuteSQL @c_SQL
                           ,N'@c_Storerkey   NVARCHAR(15)
                             ,@c_Facility    NVARCHAR(30)
                             ,@c_OtherConfig NVARCHAR(4000)'
                           ,@c_Storerkey
                           ,@c_Facility
                           ,@c_OtherConfig    
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @c_ErrMsg = 'JOB Name: '  + @c_Code
                       +', Storerkey: ' + @c_Storerkey
                       +', Facility: '  + @c_Facility
                       + ' <<' + ERROR_MESSAGE() + '>>'
      END CATCH

      IF (XACT_STATE()) = -1  
      BEGIN
         SET @n_Continue = 3 
         ROLLBACK TRAN
      END  

      UPDATE Codelkup WITH (ROWLOCK)
      SET UDF04 = CONVERT(NVARCHAR(30), getdate(), 121)
         ,Trafficcop = NULL
      WHERE ListName = 'BEJ'
      AND   Code     = @c_jobname
      AND   Storerkey= @c_Storerkey
      AND   Code2    = @c_Facility
 
      NEXT_JOB:
      FETCH NEXT FROM @CUR_JOB INTO @c_Code, @c_StoredProc
                                 ,  @c_Storerkey, @c_Facility
                                 ,  @c_OtherConfig
   END
   CLOSE @CUR_JOB
   DEALLOCATE @CUR_JOB  

QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR
   END
END

GO