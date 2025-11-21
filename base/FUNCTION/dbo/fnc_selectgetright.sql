SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************    
* ScriptName...: fnc_SelectGetRight                                               
* Programmer...: Wan                                                        
* Created On...: 17-JUL-2019                                                   
* .............:                                                               
* .............:                                                               
* Parameters...: NONE                                                          
               @c_Facility   NVARCHAR(5)   - Facility                          
               @c_StorerKey  NVARCHAR(15)  - Storer                                 
               @c_sku        NVARCHAR(20)  - Sku                                   
               @c_ConfigKey  NVARCHAR(30)  - ConfigKey                             
               @b_Success    int       - OUTPUT - 1 for success                
                                                - 0 for fail                   
               @c_Authority  NVARCHAR(30)  - OUTPUT - 1 for granted                
                                                      0 for denied    
    
* Purpose......: Create nspGetRight    
* .............: This Stored Procedure is intended to using for IDS     
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
*                   - if not exist, return @c_Authority = '0'    
*******************************************************************    
* Modification History:                                                
* Date         Author   Ver.  Purposes                                
* 17-JUL-2019  Wan      1.0   Developed from fnc_GetRight to return
*                             Result In Table
* *****************************************************************/    
CREATE FUNCTION [dbo].[fnc_SelectGetRight]
(
   @c_Facility    NVARCHAR(5), 
   @c_StorerKey   NVARCHAR(15), 
   @c_SKU         NVARCHAR(20), 
   @c_ConfigKey   NVARCHAR(30)
)
RETURNS @tConfig TABLE  
(  Authority      NVARCHAR(30)
,  ConfigOption1  NVARCHAR(50) 
,  ConfigOption2  NVARCHAR(50) 
,  ConfigOption3  NVARCHAR(50) 
,  ConfigOption4  NVARCHAR(50) 
,  ConfigOption5  NVARCHAR(4000) 
)       
AS
BEGIN   
 
   DECLARE @n_cnt          INT   -- Holds @@ROWCOUNT after certain operations    
         , @c_Authority    NVARCHAR(30) = ''
         , @c_Option1      NVARCHAR(50) = '' 
         , @c_Option2      NVARCHAR(50) = ''           
         , @c_Option3      NVARCHAR(50) = '' 
         , @c_Option4      NVARCHAR(50) = ''
         , @c_Option5      NVARCHAR(4000) = ''
   
   IF ISNULL(RTRIM(@c_ConfigKey), '') = ''
   BEGIN
      GOTO EXIT_FUNCTION
   END 
   
   /* Start - Level 2 checking - StorerConfig */    
   IF ISNULL(RTRIM(@c_Facility), '') <> ''
   BEGIN
      IF ISNULL(RTRIM(@c_StorerKey), '') <> ''
      BEGIN
         SELECT TOP 1 
                     @c_Authority = ISNULL(RTRIM(Svalue), '')
                  ,  @c_Option1 = ISNULL(RTRIM(Option1),'') 
                  ,  @c_Option2 = ISNULL(RTRIM(Option2),'')           
                  ,  @c_Option3 = ISNULL(RTRIM(Option3),'') 
                  ,  @c_Option4 = ISNULL(RTRIM(Option4),'')
                  ,  @c_Option5 = ISNULL(RTRIM(Option5),'')
         FROM  StorerConfig WITH (NOLOCK)
         WHERE StorerKey     = @c_StorerKey
         AND   Configkey     = @c_ConfigKey
         AND   Facility      = @c_Facility    
         
         SET @n_cnt = @@ROWCOUNT    
         IF (@n_cnt > 0 AND ISNULL(RTRIM(@c_Authority), '') <> '')
         BEGIN
            GOTO EXIT_FUNCTION
         END
         ELSE
         BEGIN
            SELECT TOP 1 
                     @c_Authority = ISNULL(RTRIM(Svalue), '')
                  ,  @c_Option1 = ISNULL(RTRIM(Option1),'') 
                  ,  @c_Option2 = ISNULL(RTRIM(Option2),'')           
                  ,  @c_Option3 = ISNULL(RTRIM(Option3),'') 
                  ,  @c_Option4 = ISNULL(RTRIM(Option4),'')
                  ,  @c_Option5 = ISNULL(RTRIM(Option5),'')
            FROM  StorerConfig WITH (NOLOCK)
            WHERE StorerKey = @c_StorerKey
            AND   Configkey = @c_ConfigKey
            AND  Facility  = ''     
            
            SET @n_cnt = @@ROWCOUNT    
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
         SELECT TOP 1 
                  @c_Authority = ISNULL(RTRIM(Svalue), '')
               ,  @c_Option1 = ISNULL(RTRIM(Option1),'') 
               ,  @c_Option2 = ISNULL(RTRIM(Option2),'')           
               ,  @c_Option3 = ISNULL(RTRIM(Option3),'') 
               ,  @c_Option4 = ISNULL(RTRIM(Option4),'')
               ,  @c_Option5 = ISNULL(RTRIM(Option5),'')
         FROM  StorerConfig WITH (NOLOCK)
         WHERE StorerKey     = @c_StorerKey
         AND   Configkey     = @c_ConfigKey   
         AND   Facility  = '' 
         
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
      DECLARE @c_UserDefine01 NVARCHAR(30) = '' , @c_UserDefine02 NVARCHAR(30) = ''
            , @c_UserDefine03 NVARCHAR(30) = '' , @c_UserDefine04 NVARCHAR(30) = ''
            , @c_UserDefine05 NVARCHAR(30) = '' , @c_UserDefine06 NVARCHAR(30) = ''
            , @c_UserDefine07 NVARCHAR(30) = '' , @c_UserDefine08 NVARCHAR(30) = ''
            , @c_UserDefine09 NVARCHAR(30) = '' , @c_UserDefine10 NVARCHAR(30) = ''
            , @c_UserDefine11 NVARCHAR(30) = '' , @c_UserDefine12 NVARCHAR(30) = ''
            , @c_UserDefine13 NVARCHAR(30) = '' , @c_UserDefine14 NVARCHAR(30) = ''
            , @c_UserDefine15 NVARCHAR(30) = '' , @c_UserDefine16 NVARCHAR(30) = ''
            , @c_UserDefine17 NVARCHAR(30) = '' , @c_UserDefine18 NVARCHAR(30) = ''
            , @c_UserDefine19 NVARCHAR(30) = '' , @c_UserDefine20 NVARCHAR(30) = ''   
   
      SELECT @c_UserDefine01 = ISNULL(UserDefine01,''), @c_UserDefine02 = ISNULL(UserDefine02,'')
          ,  @c_UserDefine03 = ISNULL(UserDefine03,''), @c_UserDefine04 = ISNULL(UserDefine04,'')
          ,  @c_UserDefine05 = ISNULL(UserDefine05,''), @c_UserDefine06 = ISNULL(UserDefine06,'')
          ,  @c_UserDefine07 = ISNULL(UserDefine07,''), @c_UserDefine08 = ISNULL(UserDefine08,'')
          ,  @c_UserDefine09 = ISNULL(UserDefine09,''), @c_UserDefine10 = ISNULL(UserDefine10,'')
          ,  @c_UserDefine11 = ISNULL(UserDefine11,''), @c_UserDefine12 = ISNULL(UserDefine12,'')
          ,  @c_UserDefine13 = ISNULL(UserDefine13,''), @c_UserDefine14 = ISNULL(UserDefine14,'')
          ,  @c_UserDefine15 = ISNULL(UserDefine15,''), @c_UserDefine16 = ISNULL(UserDefine16,'')
          ,  @c_UserDefine17 = ISNULL(UserDefine17,''), @c_UserDefine18 = ISNULL(UserDefine18,'')
          ,  @c_UserDefine19 = ISNULL(UserDefine19,''), @c_UserDefine20 = ISNULL(UserDefine20,'')
      FROM  Facility WITH (NOLOCK)
      WHERE Facility = @c_Facility
   
      SET @n_cnt = @@ROWCOUNT    
      IF NOT @n_cnt = 0
      BEGIN
         IF @c_ConfigKey IN (@c_UserDefine01, @c_UserDefine02, @c_UserDefine03, 
                            @c_UserDefine04, @c_UserDefine05, @c_UserDefine06, @c_UserDefine07, 
                            @c_UserDefine08, @c_UserDefine09, @c_UserDefine10, @c_UserDefine11, 
                            @c_UserDefine12, @c_UserDefine13, @c_UserDefine14, @c_UserDefine15, 
                            @c_UserDefine16, @c_UserDefine17, @c_UserDefine18, @c_UserDefine19, 
                            @c_UserDefine20) -- (ChewKP01)
         BEGIN
            SET @c_Authority = '1'
            GOTO EXIT_FUNCTION 
         END
      END
   END -- IF ISNULL(RTRIM(@c_Facility), '') <> ''
   
   SELECT @c_Authority = ISNULL(RTRIM(nSQLValue), '')
   FROM  NSqlConfig WITH (NOLOCK)
   WHERE ConfigKey = @c_ConfigKey
      
   SET @n_cnt = @@ROWCOUNT    
   IF NOT (@n_cnt = 0 OR ISNULL(RTRIM(@c_Authority), '') = '')
   BEGIN
      GOTO EXIT_FUNCTION
   END
   ELSE
   BEGIN
      SET @c_Authority = '0'
      GOTO EXIT_FUNCTION 
   END
      
   EXIT_FUNCTION: 
   INSERT INTO @tConfig ( Authority, ConfigOption1, ConfigOption2, ConfigOption3, ConfigOption4, ConfigOption5 ) 
   VALUES ( @c_Authority, @c_Option1, @c_Option2, @c_Option3, @c_Option4, @c_Option5 )

   RETURN
END   

GO