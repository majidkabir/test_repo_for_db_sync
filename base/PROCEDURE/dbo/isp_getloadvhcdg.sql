SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetLoadVHCDG                                   */
/* Creation Date: 25-Oct-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#218979                                                  */
/*                                                                      */
/* Called By: d_dw_lp_dgvolume                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author         Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetLoadVHCDG] 
(@c_VehicleNo  NVARCHAR(10))
AS
BEGIN

   DECLARE 
    @c_DGCode        NVARCHAR(20)
   ,@c_UDFColumn     NVARCHAR(30)

   ,@c_VehicleType   NVARCHAR(20)

   ,@n_DGLimit01     FLOAT
   ,@n_DGLimit02     FLOAT
   ,@n_DGLimit03     FLOAT
   ,@n_DGLimit04     FLOAT
   ,@n_DGLimit05     FLOAT
   ,@n_DGLimit06     FLOAT
   ,@n_DGLimit07     FLOAT
   ,@n_DGLimit08     FLOAT
   ,@n_DGLimit09     FLOAT
   ,@n_DGLimit10     FLOAT
   
   ,@c_UDFCol01      NVARCHAR(30)  
   ,@c_UDFCol02      NVARCHAR(30)  
   ,@c_UDFCol03      NVARCHAR(30)  
   ,@c_UDFCol04      NVARCHAR(30)  
   ,@c_UDFCol05      NVARCHAR(30)  
   ,@c_UDFCol06      NVARCHAR(30)  
   ,@c_UDFCol07      NVARCHAR(30)  
   ,@c_UDFCol08      NVARCHAR(30)  
   ,@c_UDFCol09      NVARCHAR(30)  
   ,@c_UDFCol10      NVARCHAR(30)
   
   ,@c_DGLimit01     NVARCHAR(30)
   ,@c_DGLimit02     NVARCHAR(30)
   ,@c_DGLimit03     NVARCHAR(30)
   ,@c_DGLimit04     NVARCHAR(30)
   ,@c_DGLimit05     NVARCHAR(30)
   ,@c_DGLimit06     NVARCHAR(30)
   ,@c_DGLimit07     NVARCHAR(30)
   ,@c_DGLimit08     NVARCHAR(30)
   ,@c_DGLimit09     NVARCHAR(30)
   ,@c_DGLimit10     NVARCHAR(30)
  
   
   SET @n_DGLimit01  = 0.00   
   SET @n_DGLimit02  = 0.00   
   SET @n_DGLimit03  = 0.00   
   SET @n_DGLimit04  = 0.00   
   SET @n_DGLimit05  = 0.00   
   SET @n_DGLimit06  = 0.00   
   SET @n_DGLimit07  = 0.00   
   SET @n_DGLimit08  = 0.00   
   SET @n_DGLimit09  = 0.00   
   SET @n_DGLimit10  = 0.00   
                     
   SET @c_UDFCol01   = ''  
   SET @c_UDFCol02   = ''  
   SET @c_UDFCol03   = ''              
   SET @c_UDFCol04   = ''              
   SET @c_UDFCol05   = ''              
   SET @c_UDFCol06   = ''              
   SET @c_UDFCol07   = ''              
   SET @c_UDFCol08   = ''              
   SET @c_UDFCol09   = ''              
   SET @c_UDFCol10   = ''

   SET @c_DGLimit01  = ''  
   SET @c_DGLimit02  = ''  
   SET @c_DGLimit03  = ''              
   SET @c_DGLimit04  = ''              
   SET @c_DGLimit05  = ''              
   SET @c_DGLimit06  = ''              
   SET @c_DGLimit07  = ''              
   SET @c_DGLimit08  = ''              
   SET @c_DGLimit09  = ''              
   SET @c_DGLimit10  = ''

   DECLARE C_DGSetup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT CODE, SHORT 
   FROM   CODELKUP WITH (NOLOCK)
   WHERE  LISTNAME = 'VHCUDFDGCD' 
   
   OPEN C_DGSetup 

   FETCH NEXT FROM C_DGSetup INTO @c_UDFColumn, @c_DGCode
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_UDFColumn = 'USERDEFINE01' SET @c_UDFCol01 = @c_DGCode  
      IF @c_UDFColumn = 'USERDEFINE02' SET @c_UDFCol02 = @c_DGCOde  
      IF @c_UDFColumn = 'USERDEFINE03' SET @c_UDFCol03 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE04' SET @c_UDFCol04 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE05' SET @c_UDFCol05 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE06' SET @c_UDFCol06 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE07' SET @c_UDFCol07 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE08' SET @c_UDFCol08 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE09' SET @c_UDFCol09 = @c_DGCOde              
      IF @c_UDFColumn = 'USERDEFINE10' SET @c_UDFCol10 = @c_DGCOde

      FETCH NEXT FROM C_DGSetup INTO @c_UDFColumn, @c_DGCode
   END 
   CLOSE C_DGSetup
   DEALLOCATE C_DGSetup

   SELECT  @c_VehicleType = ISNULL(RTRIM(V.VehicleType),'')
         , @c_DGLimit01 = REPLACE(ISNULL(RTRIM(V.UserDefine01),''),' ','')
         , @c_DGLimit02 = REPLACE(ISNULL(RTRIM(V.UserDefine02),''),' ','')
         , @c_DGLimit03 = REPLACE(ISNULL(RTRIM(V.UserDefine03),''),' ','')
         , @c_DGLimit04 = REPLACE(ISNULL(RTRIM(V.UserDefine04),''),' ','')
         , @c_DGLimit05 = REPLACE(ISNULL(RTRIM(V.UserDefine05),''),' ','')
         , @c_DGLimit06 = REPLACE(ISNULL(RTRIM(V.UserDefine06),''),' ','')
         , @c_DGLimit07 = REPLACE(ISNULL(RTRIM(V.UserDefine07),''),' ','')
         , @c_DGLimit08 = REPLACE(ISNULL(RTRIM(V.UserDefine08),''),' ','')
         , @c_DGLimit09 = REPLACE(ISNULL(RTRIM(V.UserDefine09),''),' ','')
         , @c_DGLimit10 = REPLACE(ISNULL(RTRIM(V.UserDefine10),''),' ','')
   FROM IDS_Vehicle V WITH (NOLOCK) 
   WHERE V.VehicleNumber = @c_VehicleNo

   IF @c_UDFCol01 = '' OR @c_DGLimit01 = '' SET @c_UDFCol01 = 'UserDefine01'
   IF @c_UDFCol02 = '' OR @c_DGLimit02 = '' SET @c_UDFCol02 = 'UserDefine02'
   IF @c_UDFCol03 = '' OR @c_DGLimit03 = '' SET @c_UDFCol03 = 'UserDefine03'
   IF @c_UDFCol04 = '' OR @c_DGLimit04 = '' SET @c_UDFCol04 = 'UserDefine04'
   IF @c_UDFCol05 = '' OR @c_DGLimit05 = '' SET @c_UDFCol05 = 'UserDefine05'
   IF @c_UDFCol06 = '' OR @c_DGLimit06 = '' SET @c_UDFCol06 = 'UserDefine06'
   IF @c_UDFCol07 = '' OR @c_DGLimit07 = '' SET @c_UDFCol07 = 'UserDefine07'
   IF @c_UDFCol08 = '' OR @c_DGLimit08 = '' SET @c_UDFCol08 = 'UserDefine08'
   IF @c_UDFCol09 = '' OR @c_DGLimit09 = '' SET @c_UDFCol09 = 'UserDefine09'
   IF @c_UDFCol10 = '' OR @c_DGLimit10 = '' SET @c_UDFCol10 = 'UserDefine10'

   SET @n_DGLimit01 = CASE CHARINDEX('/',@c_DGLimit01) WHEN 0 THEN @c_DGLimit01 
                      ELSE LEFT(@c_DGLimit01,CHARINDEX('/',@c_DGLimit01)-1) END
   SET @n_DGLimit02 = CASE CHARINDEX('/',@c_DGLimit02) WHEN 0 THEN @c_DGLimit02 
                      ELSE LEFT(@c_DGLimit02,CHARINDEX('/',@c_DGLimit02)-1) END
   SET @n_DGLimit03 = CASE CHARINDEX('/',@c_DGLimit03) WHEN 0 THEN @c_DGLimit03 
                      ELSE LEFT(@c_DGLimit03,CHARINDEX('/',@c_DGLimit03)-1) END
   SET @n_DGLimit04 = CASE CHARINDEX('/',@c_DGLimit04) WHEN 0 THEN @c_DGLimit04 
                      ELSE LEFT(@c_DGLimit04,CHARINDEX('/',@c_DGLimit04)-1) END
   SET @n_DGLimit05 = CASE CHARINDEX('/',@c_DGLimit05) WHEN 0 THEN @c_DGLimit05 
                      ELSE LEFT(@c_DGLimit05,CHARINDEX('/',@c_DGLimit05)-1) END
   SET @n_DGLimit06 = CASE CHARINDEX('/',@c_DGLimit06) WHEN 0 THEN @c_DGLimit06 
                      ELSE LEFT(@c_DGLimit06,CHARINDEX('/',@c_DGLimit06)-1) END
   SET @n_DGLimit07 = CASE CHARINDEX('/',@c_DGLimit07) WHEN 0 THEN @c_DGLimit07 
                      ELSE LEFT(@c_DGLimit07,CHARINDEX('/',@c_DGLimit07)-1) END
   SET @n_DGLimit08 = CASE CHARINDEX('/',@c_DGLimit08) WHEN 0 THEN @c_DGLimit08 
                      ELSE LEFT(@c_DGLimit08,CHARINDEX('/',@c_DGLimit08)-1) END
   SET @n_DGLimit09 = CASE CHARINDEX('/',@c_DGLimit09) WHEN 0 THEN @c_DGLimit09 
                      ELSE LEFT(@c_DGLimit09,CHARINDEX('/',@c_DGLimit09)-1) END
   SET @n_DGLimit10 = CASE CHARINDEX('/',@c_DGLimit10) WHEN 0 THEN @c_DGLimit10 
                      ELSE LEFT(@c_DGLimit10,CHARINDEX('/',@c_DGLimit10)-1) END

   IF @c_DGLimit01 = '' SET @c_DGLimit01 = '0'
   IF @c_DGLimit02 = '' SET @c_DGLimit02 = '0'
   IF @c_DGLimit03 = '' SET @c_DGLimit03 = '0'
   IF @c_DGLimit04 = '' SET @c_DGLimit04 = '0'
   IF @c_DGLimit05 = '' SET @c_DGLimit05 = '0'
   IF @c_DGLimit06 = '' SET @c_DGLimit06 = '0'
   IF @c_DGLimit07 = '' SET @c_DGLimit07 = '0'
   IF @c_DGLimit08 = '' SET @c_DGLimit08 = '0'
   IF @c_DGLimit09 = '' SET @c_DGLimit09 = '0'
   IF @c_DGLimit10 = '' SET @c_DGLimit10 = '0'
                
   SELECT @c_VehicleNo  ,@c_VehicleType
         ,@c_UDFCol01   ,@c_UDFCol02   ,@c_UDFCol03   ,@c_UDFCol04   ,@c_UDFCol05   ,@c_UDFCol06   ,@c_UDFCol07   ,@c_UDFCol08   ,@c_UDFCol09   ,@c_UDFCol10
         ,@c_DGLimit01  ,@c_DGLimit02  ,@c_DGLimit03  ,@c_DGLimit04  ,@c_DGLimit05  ,@c_DGLimit06  ,@c_DGLimit07  ,@c_DGLimit08  ,@c_DGLimit09  ,@c_DGLimit10
         ,@n_DGLimit01  ,@n_DGLimit02  ,@n_DGLimit03  ,@n_DGLimit04  ,@n_DGLimit05  ,@n_DGLimit06  ,@n_DGLimit07  ,@n_DGLimit08  ,@n_DGLimit09  ,@n_DGLimit10
         ,0.00          ,0.00          ,0.00          ,0.00          ,0.00          ,0.00          ,0.00          ,0.00          ,0.00          ,0.00

END

GO