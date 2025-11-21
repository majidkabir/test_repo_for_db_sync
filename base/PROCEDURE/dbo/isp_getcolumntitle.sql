SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetColumnTitle                                 */
/* Creation Date: 22-May-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#244027 - SkuInfo for Bond                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-10-17  Wan01    1.1   LFWM-1910 Handle for Both Exceed & SCE              */
/************************************************************************/

CREATE PROC [dbo].[isp_GetColumnTitle] 
      (  @c_ListName       NVARCHAR(10)
      ,  @c_Storerkey      NVARCHAR(15)
      ,  @c_ColName01      NVARCHAR(30) = ''  OUTPUT 
      ,  @c_ColTitle01     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName02      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle02     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName03      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle03     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName04      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle04     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName05      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle05     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName06      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle06     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName07      NVARCHAR(30) = ''  OUTPUT   
      ,  @c_ColTitle07     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName08      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle08     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName09      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle09     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName10      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle10     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName11      NVARCHAR(30) = ''  OUTPUT 
      ,  @c_ColTitle11     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName12      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle12     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName13      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle13     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName14      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle14     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName15      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle15     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName16      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle16     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName17      NVARCHAR(30) = ''  OUTPUT   
      ,  @c_ColTitle17     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName18      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle18     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName19      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle19     NVARCHAR(60) = ''  OUTPUT 
      ,  @c_ColName20      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle20     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName21      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle21     NVARCHAR(60) = ''  OUTPUT
      ,  @c_ColName22      NVARCHAR(30) = ''  OUTPUT  
      ,  @c_ColTitle22     NVARCHAR(60) = ''  OUTPUT
      )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ExecStatement   NVARCHAR(MAX)
         , @c_ExecArguments   NVARCHAR(MAX)

   DECLARE @n_No              INT
         , @n_NoOfTitleSetup  INT         
   DECLARE @c_ColTitle        NVARCHAR(60)
         , @c_ColName         NVARCHAR(30)
         , @c_No              NVARCHAR(5)

         , @c_ColNames        NVARCHAR(1000) = ''

   DECLARE @tCOLS             TABLE
         (  RowRef   INT NOT NULL IDENTITY(1,1) PRIMARY KEY
         ,  ColName  NVARCHAR(50) NOT NULL DEFAULT('')
         )

   SET @n_No            = 1
   SET @n_NoOfTitleSetup= 0
   SET @c_ExecStatement = ''
   SET @c_ExecArguments = ''
   SET @c_ColTitle      = ''
   SET @c_ColName       = ''
   SET @c_No            = ''

   SET @c_ColNames = @c_ColName01
             + '|' + @c_ColName02
             + '|' + @c_ColName03
             + '|' + @c_ColName04
             + '|' + @c_ColName05
             + '|' + @c_ColName06
             + '|' + @c_ColName07
             + '|' + @c_ColName08
             + '|' + @c_ColName09
             + '|' + @c_ColName10
             + '|' + @c_ColName11
             + '|' + @c_ColName12
             + '|' + @c_ColName13
             + '|' + @c_ColName14
             + '|' + @c_ColName15
             + '|' + @c_ColName16
             + '|' + @c_ColName17
             + '|' + @c_ColName18
             + '|' + @c_ColName19
             + '|' + @c_ColName20
             + '|' + @c_ColName21
             + '|' + @c_ColName22

   INSERT INTO @tCOLS
      (  ColName  )
   SELECT [Value]
   FROM string_split(@c_ColNames, '|') 
   WHERE [Value] <> ''

   IF NOT EXISTS ( SELECT 1 FROM @tCOLS )
   BEGIN  
      INSERT INTO @tCOLS
         (  ColName  )
      SELECT C.[Name]
      FROM SYS.COLUMNS c
      WHERE C.Object_Id = Object_Id('SkuInfo')
      AND   C.[Name] like 'Extendedfield%'
      ORDER BY C.Column_ID         
   END

   SELECT @n_NoOfTitleSetup = COUNT(1)
   FROM  CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = @c_ListName
   AND   CL.Storerkey= @c_Storerkey

   IF @n_NoOfTitleSetup = 0 GOTO QUIT

   DECLARE C_COLDESCR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ColName = ISNULL(CL.Code,0)
         ,Title = ISNULL(CL.Description,0)
         ,1
   FROM @tCOLS c
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON  CL.ListName = @c_ListName
                                       AND CL.Code = C.ColName  
                                       AND CL.Storerkey = @c_Storerkey
   ORDER BY C.RowRef
   
   OPEN C_COLDESCR 

   FETCH NEXT FROM C_COLDESCR INTO @c_ColName, @c_ColTitle, @n_NoOfTitleSetup
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_ColName01 = CASE WHEN @n_No =  1 THEN @c_ColName ELSE @c_ColName01 END
      SET @c_ColName02 = CASE WHEN @n_No =  2 THEN @c_ColName ELSE @c_ColName02 END
      SET @c_ColName03 = CASE WHEN @n_No =  3 THEN @c_ColName ELSE @c_ColName03 END
      SET @c_ColName04 = CASE WHEN @n_No =  4 THEN @c_ColName ELSE @c_ColName04 END
      SET @c_ColName05 = CASE WHEN @n_No =  5 THEN @c_ColName ELSE @c_ColName05 END
      SET @c_ColName06 = CASE WHEN @n_No =  6 THEN @c_ColName ELSE @c_ColName06 END
      SET @c_ColName07 = CASE WHEN @n_No =  7 THEN @c_ColName ELSE @c_ColName07 END
      SET @c_ColName08 = CASE WHEN @n_No =  8 THEN @c_ColName ELSE @c_ColName08 END
      SET @c_ColName09 = CASE WHEN @n_No =  9 THEN @c_ColName ELSE @c_ColName09 END
      SET @c_ColName10 = CASE WHEN @n_No = 10 THEN @c_ColName ELSE @c_ColName10 END
      SET @c_ColName11 = CASE WHEN @n_No = 11 THEN @c_ColName ELSE @c_ColName11 END
      SET @c_ColName12 = CASE WHEN @n_No = 12 THEN @c_ColName ELSE @c_ColName12 END
      SET @c_ColName13 = CASE WHEN @n_No = 13 THEN @c_ColName ELSE @c_ColName13 END
      SET @c_ColName14 = CASE WHEN @n_No = 14 THEN @c_ColName ELSE @c_ColName14 END
      SET @c_ColName15 = CASE WHEN @n_No = 15 THEN @c_ColName ELSE @c_ColName15 END
      SET @c_ColName16 = CASE WHEN @n_No = 16 THEN @c_ColName ELSE @c_ColName16 END
      SET @c_ColName17 = CASE WHEN @n_No = 17 THEN @c_ColName ELSE @c_ColName17 END
      SET @c_ColName18 = CASE WHEN @n_No = 18 THEN @c_ColName ELSE @c_ColName18 END
      SET @c_ColName19 = CASE WHEN @n_No = 19 THEN @c_ColName ELSE @c_ColName19 END
      SET @c_ColName20 = CASE WHEN @n_No = 20 THEN @c_ColName ELSE @c_ColName20 END
      SET @c_ColName21 = CASE WHEN @n_No = 21 THEN @c_ColName ELSE @c_ColName21 END
      SET @c_ColName22 = CASE WHEN @n_No = 22 THEN @c_ColName ELSE @c_ColName22 END

      SET @c_ColTitle01= CASE WHEN @n_No =  1 THEN @c_ColTitle ELSE @c_ColTitle01 END
      SET @c_ColTitle02= CASE WHEN @n_No =  2 THEN @c_ColTitle ELSE @c_ColTitle02 END
      SET @c_ColTitle03= CASE WHEN @n_No =  3 THEN @c_ColTitle ELSE @c_ColTitle03 END
      SET @c_ColTitle04= CASE WHEN @n_No =  4 THEN @c_ColTitle ELSE @c_ColTitle04 END
      SET @c_ColTitle05= CASE WHEN @n_No =  5 THEN @c_ColTitle ELSE @c_ColTitle05 END
      SET @c_ColTitle06= CASE WHEN @n_No =  6 THEN @c_ColTitle ELSE @c_ColTitle06 END
      SET @c_ColTitle07= CASE WHEN @n_No =  7 THEN @c_ColTitle ELSE @c_ColTitle07 END
      SET @c_ColTitle08= CASE WHEN @n_No =  8 THEN @c_ColTitle ELSE @c_ColTitle08 END
      SET @c_ColTitle09= CASE WHEN @n_No =  9 THEN @c_ColTitle ELSE @c_ColTitle09 END
      SET @c_ColTitle10= CASE WHEN @n_No = 10 THEN @c_ColTitle ELSE @c_ColTitle10 END
      SET @c_ColTitle11= CASE WHEN @n_No = 11 THEN @c_ColTitle ELSE @c_ColTitle11 END
      SET @c_ColTitle12= CASE WHEN @n_No = 12 THEN @c_ColTitle ELSE @c_ColTitle12 END
      SET @c_ColTitle13= CASE WHEN @n_No = 13 THEN @c_ColTitle ELSE @c_ColTitle13 END
      SET @c_ColTitle14= CASE WHEN @n_No = 14 THEN @c_ColTitle ELSE @c_ColTitle14 END
      SET @c_ColTitle15= CASE WHEN @n_No = 15 THEN @c_ColTitle ELSE @c_ColTitle15 END
      SET @c_ColTitle16= CASE WHEN @n_No = 16 THEN @c_ColTitle ELSE @c_ColTitle16 END
      SET @c_ColTitle17= CASE WHEN @n_No = 17 THEN @c_ColTitle ELSE @c_ColTitle17 END
      SET @c_ColTitle18= CASE WHEN @n_No = 18 THEN @c_ColTitle ELSE @c_ColTitle18 END
      SET @c_ColTitle19= CASE WHEN @n_No = 19 THEN @c_ColTitle ELSE @c_ColTitle19 END
      SET @c_ColTitle20= CASE WHEN @n_No = 20 THEN @c_ColTitle ELSE @c_ColTitle20 END
      SET @c_ColTitle21= CASE WHEN @n_No = 21 THEN @c_ColTitle ELSE @c_ColTitle21 END
      SET @c_ColTitle22= CASE WHEN @n_No = 22 THEN @c_ColTitle ELSE @c_ColTitle22 END

      SET @n_No = @n_No + 1
      FETCH NEXT FROM C_COLDESCR INTO @c_ColName, @c_ColTitle, @n_NoOfTitleSetup
   END 
   CLOSE C_COLDESCR
   DEALLOCATE C_COLDESCR
 
   QUIT:

   IF @n_NoOfTitleSetup = 0
   BEGIN
      SET @c_ColName01 = ''
      SET @c_ColName02 = ''
      SET @c_ColName03 = ''
      SET @c_ColName04 = ''
      SET @c_ColName05 = ''
      SET @c_ColName06 = ''
      SET @c_ColName07 = ''
      SET @c_ColName08 = ''
      SET @c_ColName09 = ''
      SET @c_ColName10 = ''
      SET @c_ColName11 = ''
      SET @c_ColName12 = ''
      SET @c_ColName13 = ''
      SET @c_ColName14 = ''
      SET @c_ColName15 = ''
      SET @c_ColName16 = ''
      SET @c_ColName17 = ''
      SET @c_ColName18 = ''
      SET @c_ColName19 = ''
      SET @c_ColName20 = ''
      SET @c_ColName21 = ''
      SET @c_ColName22 = ''
   END

END

GO