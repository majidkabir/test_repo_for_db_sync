SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************  
* ScriptName...: nspGetRight.sql                                           *  
* Programmer...: Leo Ng                                                    *  
* Created On...: 06/10/2002                                                *  
* .............:                                                           *  
* .............:                                                           *  
* Parameters...: NONE                                                      *  
               @c_Facility   NVARCHAR(5)   - Facility                          *  
               @c_StorerKey  NVARCHAR(15)  - Storer                            *   
               @c_sku        NVARCHAR(20)  - Sku                               *  
               @c_ConfigKey  NVARCHAR(30)  - ConfigKey                         *  
               @b_Success    int       - OUTPUT - 1 for success            *  
                                                - 0 for fail               *  
               @c_authority  NVARCHAR(1)   - OUTPUT - 1 for granted            *  
                                                  0 for denied  
               @n_err        int         OUTPUT - error number             *  
               @c_errmsg     NVARCHAR(250)   OUTPUT - error messsage           *  
***************************************************************************/  
  
/*******************************************************************  
* Purpose......: Create nspGetRight  
* .............: This Stored Procedure is intended to using for IDS   
*                Regional Model and it will check the authority of   
*                each passing object (could be trigger / sp) for   
*                different handle.   
*  
*              All errors in this procedure are prefixed by 616.  
*              Last Suffix Used is 01 (61601)  
*  
* *****************************************************************/  
  
/*******************************************************************  
* Algorithm....: Check the passing object in the following sequence  
* .............: 1. If @c_ConfigKey is null or empty string  
*                   Return  
*                   - @b_success = 0 (fail)  
*                   - @c_authority = 0 (deny)  
*                   - @n_err = 61601  
*                   - @c_errmsg = 'ConfigKey is null or empty string!'  
*                2. SkuConfig Table - StorerKey + Sku + ConfigType  
*                   - Retrieve by using @c_StorerKey + @c_sku +   
*                     @c_ConfigKey  
*                   - if exist, return corresponding @c_authority  
*                   - if not exist or data is null or blank or not  
*                     equal to '0' or '1', goto next level checking   
*                     - StorerConfig  
*                3. StorerConfig Table - StorerKey + Configkey + Facility  
*                   - Retrieve by using @c_StorerKey + @c_ConfigKey + @c_Facility  
*                   - if exist, return corresponding @c_authority  
*                   - if not exist, retrieve by using @c_StorerKey + @c_ConfigKey  
*                   - if exist, return corresponding @c_authority  
*                   - if not exist or svalue is null or blank or not  
*                     equal to '0' or '1', goto next level checking   
*                     - Facility  
*                4. Facility Table - Facility  
*                   - Retrieve by using @c_Facility  
*                   - Search for the configkey in UserDefine01 - 20  
*                   - if exist, return @c_authority = '1'  
*                   - if not exist, goto next level checking -   
*                     nsqlconfig  
*                5. nsqlconfig Table - Configkey  
*                   - Retrieve by using @c_ConfigKey  
*                   - if exist, return corresponding @c_authority  
*                   - if not exist, return @c_authority = '0'  
* *****************************************************************/  
  
/*******************************************************************  
* References...:   
* .............:   
* *****************************************************************/  
  
  
/*******************************************************************  
* Modification History:                                              
* Date         Author    Ver.  Purposes                              
* 06-Oct-2002  Leo Ng    1.0  Initial Cut  
* 23-Sep-2008  KC    1.1  SOS#115735 Add new primarykey Facility  
*           to StorerConfig  
* 04-Oct-2009  SHONG     1.2   Replace User Define Function with System Function  
* 16-Feb-2012  ChewKP    1.3   Bug Fix  
* 24-Apr-2012  NJOW01    1.4   Change @c_authority from NVARCHAR(1) to NVARCHAR(10)
* 31-May-2016  NJOW02    1.5   370148 - Add option1 to option5 fields and Change 
*                              @c_authority to NVARCHAR(30)
*                                
* *****************************************************************/  
  
/*****************************************************************/  
/* Start Create Procedure Here                                   */  
/*****************************************************************/  
CREATE PROC    [dbo].[nspGetRight]  
               @c_Facility   NVARCHAR(5)         ,   
               @c_StorerKey  NVARCHAR(15)        ,   
               @c_sku        NVARCHAR(20)        ,   
               @c_ConfigKey  NVARCHAR(30)        ,   
               @b_Success    int           OUTPUT,   
               @c_authority  NVARCHAR(30)  OUTPUT,  --NJOW02
               @n_err        INT           OUTPUT,  
               @c_errmsg     NVARCHAR(250) OUTPUT,
               @c_Option1    NVARCHAR(50) = '' OUTPUT, --NJOW02
               @c_Option2    NVARCHAR(50) = '' OUTPUT,
               @c_Option3    NVARCHAR(50) = '' OUTPUT,
               @c_Option4    NVARCHAR(50) = '' OUTPUT,
               @c_Option5    NVARCHAR(4000) = '' OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   DECLARE          
      @n_continue    int      ,    
      @n_starttcnt   int      , -- Holds the current transaction count  
      @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations  
      @c_preprocess  NVARCHAR(250), -- preprocess  
      @c_pstprocess  NVARCHAR(250), -- post process  
      @n_err2  int            , -- For Additional Error Detection  
      @b_debug int              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map  
  
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg='',@n_err2=0  
   SELECT @b_debug = 0  
     
   SELECT @c_authority = 0  
  
   /* Start - Validate @c_ConfigKey - must not be null or empty */  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      If @b_debug > 0  
      Begin  
         Print 'Validate @c_ConfigKey...'  
      End  
      If ISNULL(RTRIM(@c_ConfigKey),'') = ''  
      Begin  
         Select @b_Success    = 0,   
                @c_authority  = 0,   
                @n_err        = 61601,   
                @c_errmsg     = 'Invalid ConfigKey parameter - (Null / Empty)!!!',   
                @n_continue   = 3  
      End  
   End  
   /* End - Validate @c_ConfigKey - must not be null or empty */  
     
   /* Start - Level 1 checking - SkuConfig */  
/*  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      If @b_debug > 0  
      Begin  
         Print 'Level 1 checking - SkuConfig...'  
      End  
      Select @c_authority = dbo.fnc_RTRIM(dbo.fnc_LTrim(Data))  
      From SkuConfig (NOLOCK)  
       Where StorerKey    = @c_StorerKey  
         And Sku          = @c_Sku  
         And ConfigType   = @c_ConfigKey  
      Select @n_cnt = @@rowcount  
      IF NOT (@n_cnt = 0 or ISNULL(RTRIM(@c_authority),'') = '')  
      Begin  
         Select @b_Success    = 1,   
                @n_continue   = 4  
      End  
   End  
*/  
   /* End - Level 1 checking - SkuConfig */  
     
   /* Start - Level 2 checking - StorerConfig */  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      -- SOS#115735 include facility in storerconfig filtering - S  
      IF ISNULL(RTRIM(@c_Facility),'') <> ''  
      BEGIN  
         IF ISNULL(RTRIM(@c_StorerKey),'') <> ''  
         BEGIN  
            If @b_debug > 0  
            Begin  
               Print 'Level 2 checking - StorerConfig with facility...'  
            End  
  
            SELECT TOP 1 @c_Authority = ISNULL(RTRIM(Svalue),''),
                         @c_Option1 = ISNULL(Option1,''), --NJOW02
                         @c_Option2 = ISNULL(Option2,''), 
                         @c_Option3 = ISNULL(Option3,''), 
                         @c_Option4 = ISNULL(Option4,''), 
                         @c_Option5 = ISNULL(Option5,'')
            From StorerConfig (NOLOCK)  
             Where StorerKey    = @c_StorerKey  
               And Configkey    = @c_ConfigKey  
               AND Facility     = @c_Facility  
  
            Select @n_cnt = @@rowcount  
            IF NOT (@n_cnt = 0 or ISNULL(RTRIM(@c_authority),'') = '')  
            Begin  
               Select @b_Success    = 1,   
                      @n_continue   = 4  
            End  
            ELSE  
            -- facility defaulted to blank in storerconfig setup   
            -- blank facility means config applies to all facilities  
            BEGIN  
               If @b_debug > 0  
               Begin  
                  Print 'Level 2 checking - StorerConfig no facility...'  
               End  
  
               Select TOP 1 @c_authority = ISNULL(RTRIM(Svalue),''),  
                            @c_Option1 = ISNULL(Option1,''), --NJOW02
                            @c_Option2 = ISNULL(Option2,''), 
                            @c_Option3 = ISNULL(Option3,''), 
                            @c_Option4 = ISNULL(Option4,''), 
                            @c_Option5 = ISNULL(Option5,'')
               From StorerConfig (NOLOCK)  
                Where StorerKey    = @c_StorerKey  
                  And Configkey    = @c_ConfigKey  
                  AND ISNULL(RTRIM(Facility),'')  = ''   
  
               Select @n_cnt = @@rowcount  
               IF NOT (@n_cnt = 0 or ISNULL(RTRIM(@c_authority),'') = '')  
               Begin  
                  Select @b_Success    = 1,   
                         @n_continue   = 4  
               End  
            END        
         End  
      END  
      -- SOS#115735 include facility in storerconfig filtering - E  
      ELSE  
      BEGIN  
         IF ISNULL(RTRIM(@c_StorerKey),'') <> ''  
         BEGIN  
            If @b_debug > 0  
            Begin  
               Print 'Level 2 checking - StorerConfig...'  
            End  
  
            Select TOP 1 @c_authority = ISNULL(RTRIM(Svalue),''),  
                         @c_Option1 = ISNULL(Option1,''), --NJOW02
                         @c_Option2 = ISNULL(Option2,''), 
                         @c_Option3 = ISNULL(Option3,''), 
                         @c_Option4 = ISNULL(Option4,''), 
                         @c_Option5 = ISNULL(Option5,'')
            From StorerConfig (NOLOCK)  
             Where StorerKey    = @c_StorerKey  
               And Configkey    = @c_ConfigKey  
  
            Select @n_cnt = @@ROWCOUNT  
            IF NOT (@n_cnt = 0 or ISNULL(RTRIM(@c_authority),'') = '')  
            Begin  
               Select @b_Success    = 1,   
                      @n_continue   = 4  
            End  
         End  
      END -- facility is blank  
   End   
   /* End - Level 2 checking - StorerConfig */  
     
   /* Start - Level 3 checking - Facility */  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      IF ISNULL(RTRIM(@c_Facility),'') <> ''  
      BEGIN  
         If @b_debug > 0  
         Begin  
            Print 'Level 3 checking - Facility...'  
         End  
         Declare @c_UserDefine01 NVARCHAR(30),   
                 @c_UserDefine02 NVARCHAR(30),   
                 @c_UserDefine03 NVARCHAR(30),   
                 @c_UserDefine04 NVARCHAR(30),   
                 @c_UserDefine05 NVARCHAR(30),   
                 @c_UserDefine06 NVARCHAR(30),   
                 @c_UserDefine07 NVARCHAR(30),   
                 @c_UserDefine08 NVARCHAR(30),   
                 @c_UserDefine09 NVARCHAR(30),   
                 @c_UserDefine10 NVARCHAR(30),   
                 @c_UserDefine11 NVARCHAR(30),   
                 @c_UserDefine12 NVARCHAR(30),   
                 @c_UserDefine13 NVARCHAR(30),   
                 @c_UserDefine14 NVARCHAR(30),   
                 @c_UserDefine15 NVARCHAR(30),   
                 @c_UserDefine16 NVARCHAR(30),   
                 @c_UserDefine17 NVARCHAR(30),   
                 @c_UserDefine18 NVARCHAR(30),   
                 @c_UserDefine19 NVARCHAR(30),   
                 @c_UserDefine20 NVARCHAR(30)  
        
         Select @c_UserDefine01 = UserDefine01,   
                @c_UserDefine02 = UserDefine02,   
                @c_UserDefine03 = UserDefine03,   
                @c_UserDefine04 = UserDefine04,   
                @c_UserDefine05 = UserDefine05,   
                @c_UserDefine06 = UserDefine06,   
                @c_UserDefine07 = UserDefine07,   
                @c_UserDefine08 = UserDefine08,   
                @c_UserDefine09 = UserDefine09,   
                @c_UserDefine10 = UserDefine10,   
                @c_UserDefine11 = UserDefine11,   
                @c_UserDefine12 = UserDefine12,   
                @c_UserDefine13 = UserDefine13,   
                @c_UserDefine14 = UserDefine14,   
                @c_UserDefine15 = UserDefine15,   
                @c_UserDefine16 = UserDefine16,   
                @c_UserDefine17 = UserDefine17,   
                @c_UserDefine18 = UserDefine18,   
                @c_UserDefine19 = UserDefine19,   
                @c_UserDefine20 = UserDefine20   
           From Facility (NOLOCK)  
          Where Facility = @c_Facility  
          Select @n_cnt = @@rowcount  
         If not @n_cnt = 0  
         Begin  
            If @c_ConfigKey in (@c_UserDefine01, @c_UserDefine02, @c_UserDefine03, @c_UserDefine04,   
                                @c_UserDefine05, @c_UserDefine06, @c_UserDefine07, @c_UserDefine08,   
                                @c_UserDefine09, @c_UserDefine10, @c_UserDefine11, @c_UserDefine12,   
                                @c_UserDefine13, @c_UserDefine14, @c_UserDefine15, @c_UserDefine16,   
                                @c_UserDefine17, @c_UserDefine18, @c_UserDefine19, @c_UserDefine20) -- (ChewKP01)  
            Begin  
               Select @b_Success    = 1,   
                      @c_authority  = '1',   
                      @n_continue   = 4  
            End  
         End  
      End   
   End  
   /* Start - Level 3 checking - Facility */  
  
   /* Start - Level 4 checking - NSqlConfig */  
   If @n_continue = 1 or @n_continue = 2  
   Begin  
      If @b_debug > 0  
      Begin  
         Print 'Level 4 checking - NSqlConfig...'  
      End  
  
      Select @c_authority = ISNULL(RTRIM(nSQLValue),'')  
      From  NSqlConfig (NOLOCK)  
      Where ConfigKey    = @c_ConfigKey  
      Select @n_cnt = @@rowcount  
      IF NOT (@n_cnt = 0 or ISNULL(RTRIM(@c_authority),'') = '')  
      Begin  
         Select @b_Success    = 1,   
                @n_continue   = 4  
      End  
      Else  
      Begin  
         Select @b_Success    = 1,   
                @c_authority  = '0',  
                @n_continue   = 4  
      End  
   End  
   /* End - Level 4 checking - NSqlConfig */  
     
   /* End Main Processing */  
   /* Return Statement */  
  
   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt   
      BEGIN  
         ROLLBACK TRAN  
      END       
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt   
         BEGIN  
            COMMIT TRAN  
         END            
      END            
      execute nsp_logerror @n_err, @c_errmsg, 'nspGetRight'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      /* Error Did Not Occur , Return Normally */  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt   
         BEGIN  
            COMMIT TRAN  
         END            
      RETURN  
   END  
  
   /* End Return Statement */            
       
END 

GO