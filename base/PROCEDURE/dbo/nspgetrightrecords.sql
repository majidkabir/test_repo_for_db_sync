SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: nspGetRightRecords                                          */
/* Creation Date: 24-Mar-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: When records added into ITRN (ntrItrnAdd)                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author       Purposes                                   */
/* 07-May-2009  Leong        SOS# 135041, 134750 - Extend field size    */
/************************************************************************/
CREATE PROC    [dbo].[nspGetRightRecords]
               @c_Facility   NVARCHAR(5)         , 
               @c_StorerKey  NVARCHAR(15)        , 
               @c_SKU        NVARCHAR(20)        , 
               @b_Success    int       OUTPUT, 
               @n_Err        int       OUTPUT,
               @c_ErrMsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 

   DECLARE        @n_continue int        ,  
   @n_starttcnt   int      , -- Holds the current transaction count
   @n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
   @c_preprocess NVARCHAR(250) , -- preprocess
   @c_pstprocess NVARCHAR(250) , -- post process
   @n_Err2 int             , -- For Additional Error Detection
   @b_debug int              -- Debug 0 - OFF, 1 - Show ALL, 2 - Map

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_Err=0,@n_cnt = 0,@c_ErrMsg='',@n_Err2=0
   SELECT @b_debug = 0
   
   -- DECLARE @t_Rights TABLE ( ConfigKey NVARCHAR(30), sValue NVARCHAR(10) )
   DECLARE @t_Rights TABLE ( ConfigKey NVARCHAR(30), sValue NVARCHAR(30) ) -- SOS# 135041, 134750

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- SOS#115735 include Facility in storerconfig filtering - S
      IF RTRIM(@c_StorerKey) IS NOT NULL AND RTRIM(@c_StorerKey) <> ''
      BEGIN
         IF RTRIM(@c_Facility) IS NOT NULL AND RTRIM(@c_Facility) <> ''
         BEGIN
            INSERT INTO @t_Rights 
            Select ConfigKey, Svalue
            From StorerConfig WITH (NOLOCK)
             Where StorerKey    = @c_StorerKey
               AND Facility     = @c_Facility
               AND (sValue <> '' AND sValue <> '0')
         END
      
         INSERT INTO @t_Rights 
         SELECT ISNULL(RTRIM(StorerConfig.ConfigKey),''), ISNULL(RTRIM(StorerConfig.Svalue),'')
         FROM  StorerConfig (nolock) 
         LEFT OUTER JOIN @t_Rights R ON R.ConfigKey = StorerConfig.ConfigKey 
         WHERE StorerConfig.StorerKey  = @c_StorerKey
           AND ( StorerConfig.Facility = '' OR StorerConfig.Facility IS NULL )
           AND ( StorerConfig.sValue <> '' AND StorerConfig.sValue <> '0') 
           AND R.ConfigKey IS NULL 
      END 
   END
   /* End - Level 2 checking - StorerConfig */
   
   /* Start - Level 3 checking - Facility */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF RTRIM(@c_Facility) IS NOT NULL AND RTRIM(@c_Facility) <> ''
      BEGIN
         Declare @c_userdefine01 NVARCHAR(30), 
                 @c_userdefine02 NVARCHAR(30), 
                 @c_userdefine03 NVARCHAR(30), 
                 @c_userdefine04 NVARCHAR(30), 
                 @c_userdefine05 NVARCHAR(30), 
                 @c_userdefine06 NVARCHAR(30), 
                 @c_userdefine07 NVARCHAR(30), 
                 @c_userdefine08 NVARCHAR(30), 
                 @c_userdefine09 NVARCHAR(30), 
                 @c_userdefine10 NVARCHAR(30), 
                 @c_userdefine11 NVARCHAR(30), 
                 @c_userdefine12 NVARCHAR(30), 
                 @c_userdefine13 NVARCHAR(30), 
                 @c_userdefine14 NVARCHAR(30), 
                 @c_userdefine15 NVARCHAR(30), 
                 @c_userdefine16 NVARCHAR(30), 
                 @c_userdefine17 NVARCHAR(30), 
                 @c_userdefine18 NVARCHAR(30), 
                 @c_userdefine19 NVARCHAR(30), 
                 @c_userdefine20 NVARCHAR(30)
      
         Select @c_userdefine01 = UserDefine01, 
                @c_userdefine02 = UserDefine02, 
                @c_userdefine03 = UserDefine03, 
                @c_userdefine04 = UserDefine04, 
                @c_userdefine05 = UserDefine05, 
                @c_userdefine06 = UserDefine06, 
                @c_userdefine07 = UserDefine07, 
                @c_userdefine08 = UserDefine08, 
                @c_userdefine09 = UserDefine09, 
                @c_userdefine10 = UserDefine10, 
                @c_userdefine11 = UserDefine11, 
                @c_userdefine12 = UserDefine12, 
                @c_userdefine13 = UserDefine13, 
                @c_userdefine14 = UserDefine14, 
                @c_userdefine15 = UserDefine15, 
                @c_userdefine16 = UserDefine16, 
                @c_userdefine17 = UserDefine17, 
                @c_userdefine18 = UserDefine18, 
                @c_userdefine19 = UserDefine19, 
                @c_userdefine20 = UserDefine20 
           From Facility (nolock)
          Where Facility = @c_Facility

         Select @n_cnt = @@rowcount
         IF not @n_cnt = 0
         BEGIN 
            DECLARE @nIndex int, 
                    @cUserDefine NVARCHAR(30)


            SET @nIndex = 1 
            WHILE @nIndex <= 20
            BEGIN 
               SELECT @cUserDefine =
                  CASE @nIndex 
                      WHEN 1 THEN @c_userdefine01
                      WHEN 2 THEN @c_userdefine02
                      WHEN 3 THEN @c_userdefine03
                      WHEN 4 THEN @c_userdefine04
                      WHEN 5 THEN @c_userdefine05
                      WHEN 6 THEN @c_userdefine06
                      WHEN 7 THEN @c_userdefine07
                      WHEN 8 THEN @c_userdefine08
                      WHEN 9 THEN @c_userdefine09
                      WHEN 10 THEN @c_userdefine10
                      WHEN 11 THEN @c_userdefine11
                      WHEN 12 THEN @c_userdefine12
                      WHEN 13 THEN @c_userdefine13
                      WHEN 14 THEN @c_userdefine14
                      WHEN 15 THEN @c_userdefine15
                      WHEN 16 THEN @c_userdefine16
                      WHEN 17 THEN @c_userdefine17
                      WHEN 18 THEN @c_userdefine18
                      WHEN 19 THEN @c_userdefine19
                      WHEN 20 THEN @c_userdefine20 
                      ELSE ''
                  END

               IF ISNULL(RTRIM(@cUserDefine),'') <> '' 
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM @t_Rights WHERE ConfigKey = @cUserDefine)
                  BEGIN
                    INSERT INTO @t_Rights VALUES (@cUserDefine, '1')
                  END 
               END
               SET @nIndex = @nIndex + 1
            END
         End
      End 
   End
   /* Start - Level 3 checking - Facility */

   /* Start - Level 4 checking - NSqlConfig */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @b_debug > 0
      BEGIN
         Print 'Level 4 checking - NSqlConfig...'
      End

      INSERT INTO @t_Rights
      SELECT NSqlConfig.ConfigKey, NSqlConfig.NSQLValue
      FROM NSqlConfig WITH (NOLOCK) 
      LEFT OUTER JOIN @t_Rights R ON R.ConfigKey = NSqlConfig.ConfigKey 
      WHERE (NSQLValue <> '0' AND IsNULL(RTRIM(NSQLValue), '') <> '') --SOS#123424
      AND   R.ConfigKey IS NULL 

   End
   /* End - Level 4 checking - NSqlConfig */
   
   SELECT * FROM @t_Rights 

END

GO