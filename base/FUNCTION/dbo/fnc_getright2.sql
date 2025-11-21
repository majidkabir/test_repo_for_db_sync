SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************    
* ScriptName...: fnc_GetRight2                                               
* Programmer...:                                                          
* Created On...: 17/08/2021 WMS-17727                                                   
* .............:                                                               
* .............:                                                               
* Parameters...: NONE                                                          
               @c_Facility   NVARCHAR(5)   - Facility                          
               @c_StorerKey  NVARCHAR(15)  - Storer                                 
               @c_sku        NVARCHAR(20)  - Sku                                   
               @c_ConfigKey  NVARCHAR(30)  - ConfigKey                             
               @b_Success    int       - OUTPUT - 1 for success                
                                                - 0 for fail                   
               @c_Authority  NVARCHAR(1)   - OUTPUT - 1 for granted                
                                                      0 for denied    
               @n_err        int             OUTPUT - error number                 
               @c_errmsg     NVARCHAR(250)   OUTPUT - error messsage               
    
* Purpose......: Create nspGetRight    
* .............: This Stored Procedure is intended to using for LFL     
*                Regional Model and it will check the authority of     
*                each passing object (could be trigger / sp) for     
*                different handle.     
*    
*              All errors in this procedure are prefixed by 616.    
*              Last Suffix Used is 01 (61601)    
*    
* Algorithm....: Check the passing object in the following sequence    
* .............: 1. If @c_ConfigKey is null or empty string    
*                   Return    
*                   - @b_success = 0 (fail)    
*                   - @c_Authority = 0 (deny)    
*                   - @n_err = 61601    
*                   - @c_errmsg = 'ConfigKey is null or empty string!'    
*                2. SkuConfig Table - StorerKey + Sku + ConfigType    
*                   - Retrieve by using @c_StorerKey + @c_sku +     
*                     @c_ConfigKey    
*                   - if exist, return corresponding @c_Authority    
*                   - if not exist or data is null or blank or not    
*                     equal to '0' or '1', goto next level checking     
*                     - StorerConfig    
*                3. StorerConfig Table - StorerKey + Configkey + Facility    
*                   - Retrieve by using @c_StorerKey + @c_ConfigKey + @c_Facility    
*                   - if exist, return corresponding @c_Authority    
*                   - if not exist, retrieve by using @c_StorerKey + @c_ConfigKey    
*                   - if exist, return corresponding @c_Authority    
*                   - if not exist or svalue is null or blank or not    
*                     equal to '0' or '1', goto next level checking     
*                     - Facility    
*                4. Facility Table - Facility    
*                   - Retrieve by using @c_Facility    
*                   - Search for the configkey in UserDefine01 - 20    
*                   - if exist, return @c_Authority = '1'    
*                   - if not exist, goto next level checking -     
*                     nsqlconfig    
*                5. nsqlconfig Table - Configkey    
*                   - Retrieve by using @c_ConfigKey    
*                   - if exist, return corresponding @c_Authority    
*                   - if not exist, return @c_Authority = ''    
*******************************************************************    
* Modification History:                                                
* Date         Author    Ver.  Purposes                                
* *****************************************************************/    


CREATE FUNCTION [dbo].[fnc_GetRight2]
(
   @c_Facility    NVARCHAR(5), 
   @c_StorerKey   NVARCHAR(15), 
   @c_SKU         NVARCHAR(20), 
   @c_ConfigKey   NVARCHAR(30)
)
RETURNS @tGetRight TABLE       
(     Storerkey   NVARCHAR(15) NULL,
      Facility    NVARCHAR(5)  NULL,
      Configkey   NVARCHAR(30) NULL,
      Authority   NVARCHAR(30) NULL,
      Option1     NVARCHAR(50) NULL, 
      Option2     NVARCHAR(50) NULL, 
      Option3     NVARCHAR(50) NULL, 
      Option4     NVARCHAR(50) NULL, 
      Option5     NVARCHAR(4000) NULL
)  
AS
BEGIN   
   DECLARE @n_cnt           INT,  -- Holds @@ROWCOUNT after certain operations    
           @c_Authority     NVARCHAR(30),
           @C_Option1      NVARCHAR(50), 
           @C_Option2      NVARCHAR(50), 
           @C_Option3      NVARCHAR(50), 
           @C_Option4      NVARCHAR(50), 
           @C_Option5      NVARCHAR(4000),
           @c_GetStorerkey NVARCHAR(15),
           @c_GetFacility  NVARCHAR(5),
           @c_GetConfigkey NVARCHAR(30)
                                               
   SET @c_Authority = ''    
   SELECT @C_Option1='', @C_Option2='', @C_Option3='', @C_Option4='', @C_Option5='', @c_GetStorerkey='', @c_GetFacility='', @c_GetConfigkey=''
   
   IF ISNULL(RTRIM(@c_ConfigKey), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END 
   
   /* Start - Level 2 checking - StorerConfig */    
   IF ISNULL(RTRIM(@c_Facility), '') <> ''
   BEGIN
      IF ISNULL(RTRIM(@c_StorerKey), '') <> ''
      BEGIN
         SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue), '')         
                     ,@C_GetStorerkey = ISNULL(RTRIM(Storerkey), '')
                     ,@C_GetFacility  = ISNULL(RTRIM(Facility), '')
                     ,@C_GetConfigkey  = ISNULL(RTRIM(Configkey), '')
                     ,@C_Option1 = ISNULL(RTRIM(Option1), '')
                     ,@C_Option2 = ISNULL(RTRIM(Option2), '')
                     ,@C_Option3 = ISNULL(RTRIM(Option3), '')
                     ,@C_Option4 = ISNULL(RTRIM(Option4), '')
                     ,@C_Option5 = ISNULL(RTRIM(Option5), '')
         FROM   StorerConfig WITH (NOLOCK)
         WHERE StorerKey     = @c_StorerKey
         AND   Configkey     = @c_ConfigKey
         AND   Facility      = @c_Facility    
         
         SELECT @n_cnt = @@ROWCOUNT    
         IF (@n_cnt > 0 AND ISNULL(RTRIM(@c_Authority), '') <> '')
         BEGIN
            GOTO EXIT_FUNCTION
         END
         ELSE
         BEGIN
            SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue), '')
                        ,@C_GetStorerkey = ISNULL(RTRIM(Storerkey), '')
                        ,@C_GetFacility  = ISNULL(RTRIM(Facility), '')
                        ,@C_GetConfigkey  = ISNULL(RTRIM(Configkey), '')
                        ,@C_Option1 = ISNULL(RTRIM(Option1), '')
                        ,@C_Option2 = ISNULL(RTRIM(Option2), '')
                        ,@C_Option3 = ISNULL(RTRIM(Option3), '')
                        ,@C_Option4 = ISNULL(RTRIM(Option4), '')
                        ,@C_Option5 = ISNULL(RTRIM(Option5), '')
            FROM   StorerConfig WITH (NOLOCK)
            WHERE StorerKey     = @c_StorerKey
            AND   Configkey     = @c_ConfigKey
            AND  (Facility  = '' OR Facility IS NULL)     
            
            SELECT @n_cnt = @@ROWCOUNT    
            IF NOT (@n_cnt = 0 OR ISNULL(RTRIM(@c_Authority), '') = '')
            BEGIN 
               GOTO EXIT_FUNCTION 
            END
         END
      END
   END  
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_StorerKey), '') <> ''
      BEGIN 
         SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue), '')
                     ,@C_GetStorerkey = ISNULL(RTRIM(Storerkey), '')
                     ,@C_GetFacility  = ISNULL(RTRIM(Facility), '')
                     ,@C_GetConfigkey  = ISNULL(RTRIM(Configkey), '')
                     ,@C_Option1 = ISNULL(RTRIM(Option1), '')
                     ,@C_Option2 = ISNULL(RTRIM(Option2), '')
                     ,@C_Option3 = ISNULL(RTRIM(Option3), '')
                     ,@C_Option4 = ISNULL(RTRIM(Option4), '')
                     ,@C_Option5 = ISNULL(RTRIM(Option5), '')         
         FROM   StorerConfig WITH (NOLOCK)
         WHERE StorerKey     = @c_StorerKey
         AND   Configkey     = @c_ConfigKey   
         AND  (Facility  = '' OR Facility IS NULL)  
         
         SELECT @n_cnt = @@ROWCOUNT    
         IF NOT (@n_cnt = 0 OR ISNULL(RTRIM(@c_Authority), '') = '')
         BEGIN 
            GOTO EXIT_FUNCTION 
         END
      END
   END -- facility is blank
      
/* End - Level 2 checking - StorerConfig */    
       
/* Start - Level 3 checking - Facility */     
IF ISNULL(RTRIM(@c_Facility), '') <> '' 
BEGIN
   DECLARE @c_UserDefine01 NVARCHAR(30), @c_UserDefine02 NVARCHAR(30), @c_UserDefine03 
           NVARCHAR(30), @c_UserDefine04 NVARCHAR(30), @c_UserDefine05 
           NVARCHAR(30), @c_UserDefine06 NVARCHAR(30), @c_UserDefine07 
           NVARCHAR(30), @c_UserDefine08 NVARCHAR(30), @c_UserDefine09 
           NVARCHAR(30), @c_UserDefine10 NVARCHAR(30), @c_UserDefine11 
           NVARCHAR(30), @c_UserDefine12 NVARCHAR(30), @c_UserDefine13 
           NVARCHAR(30), @c_UserDefine14 NVARCHAR(30), @c_UserDefine15 
           NVARCHAR(30), @c_UserDefine16 NVARCHAR(30), @c_UserDefine17 
           NVARCHAR(30), @c_UserDefine18 NVARCHAR(30), @c_UserDefine19 
           NVARCHAR(30), @c_UserDefine20 NVARCHAR(30)    
   
   SELECT @c_UserDefine01 = UserDefine01, @c_UserDefine02 = UserDefine02, @c_UserDefine03 = 
          UserDefine03, @c_UserDefine04 = UserDefine04, @c_UserDefine05 = 
          UserDefine05, @c_UserDefine06 = UserDefine06, @c_UserDefine07 = 
          UserDefine07, @c_UserDefine08 = UserDefine08, @c_UserDefine09 = 
          UserDefine09, @c_UserDefine10 = UserDefine10, @c_UserDefine11 = 
          UserDefine11, @c_UserDefine12 = UserDefine12, @c_UserDefine13 = 
          UserDefine13, @c_UserDefine14 = UserDefine14, @c_UserDefine15 = 
          UserDefine15, @c_UserDefine16 = UserDefine16, @c_UserDefine17 = 
          UserDefine17, @c_UserDefine18 = UserDefine18, @c_UserDefine19 = 
          UserDefine19, @c_UserDefine20 = UserDefine20
   FROM   Facility WITH (NOLOCK)
   WHERE Facility = @c_Facility
   
   SELECT @n_cnt = @@ROWCOUNT    
   IF NOT @n_cnt = 0
   BEGIN
      IF @c_ConfigKey IN (@c_UserDefine01, @c_UserDefine02, @c_UserDefine03, 
                         @c_UserDefine04, @c_UserDefine05, @c_UserDefine06, @c_UserDefine07, 
                         @c_UserDefine08, @c_UserDefine09, @c_UserDefine10, @c_UserDefine11, 
                         @c_UserDefine12, @c_UserDefine13, @c_UserDefine14, @c_UserDefine15, 
                         @c_UserDefine16, @c_UserDefine17, @c_UserDefine18, @c_UserDefine19, 
                         @c_UserDefine20) 
      BEGIN
         SET @c_Authority = '1'
         SET @c_GetFacility = @c_Facility
         SET @c_GetConfigkey = @c_Configkey

         GOTO EXIT_FUNCTION 
      END
   END
END -- IF ISNULL(RTRIM(@c_Facility), '') <> ''
   
SELECT @c_Authority = ISNULL(RTRIM(nSQLValue), '')
FROM   NSqlConfig WITH (NOLOCK)
WHERE ConfigKey = @c_ConfigKey
   
SELECT @n_cnt = @@ROWCOUNT    
IF NOT (@n_cnt = 0 OR ISNULL(RTRIM(@c_Authority), '') = '')
BEGIN
   GOTO EXIT_FUNCTION
END
ELSE
BEGIN
   SET @c_Authority = '' --'0'
   GOTO EXIT_FUNCTION 
END
   
EXIT_FUNCTION: 

INSERT INTO @tGetRight ( Storerkey, Facility, Configkey, Authority, Option1, Option2, Option3, Option4, Option5)
VALUES ( @c_GetStorerkey, @c_GetFacility, @c_GetConfigkey, @c_Authority, @C_Option1, @C_Option2, @C_Option3, @C_Option4, @C_Option5)                       
                                            
RETURN                                 
                                       
END   

GO