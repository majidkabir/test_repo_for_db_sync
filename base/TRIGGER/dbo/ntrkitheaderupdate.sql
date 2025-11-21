SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrKitHeaderUpdate                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  KIT Header Update Transaction                              */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When update records                                       */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                               */
/* Date         Author  Ver   Purposes                                    */
/* 08-July-2005 Vicky         Add KITLOG as Configkey for Interface       */
/* 26-Sept-2006 Vicky         Get Status from Inserted                    */
/* 03-Oct-2006  Vicky         Take out Else during checking on KITLOG flag*/
/* 31-May-2007  Shong         Only Check Reason Code when Continue = 1, 2 */
/* 03-Aug-2007  Wanyt         SOS#82310: Error 34                         */
/* 17-Mar-2009  TLTING        Change user_name() to SUSER_SNAME()         */
/* 22-May-2012  TLTING01      DM Integrity issue - Update editdate for    */
/*                            status < '9'                                */
/* 28-Oct-2013  TLTING        Review Editdate column update               */
/* 21-APR-2014  YTWan   1.3   SOS#304838 - ANF - Allocation strategy for  */
/*                            Transfer (Wan01)                            */ 
/* 28-MAR-2016  CSCHONG 1.4   SOS#364463 Auto Calculate Lottable06 (CS01) */
/* 18-APR-2016  NJOW01  1.5   367627-Add pre-finalize process             */
/* 15-Jul-2016  MCTang  1.6   Enhance Generaic Trigger Interface (MC03)   */
/* 18-Sep-2017  NJOW02  1.7   WMS-2930 Move completed qty to new kit      */
/*                            work order and finalize                     */
/* 30-Oct-2019  WLChooi 1.8   WMS-10947 - Kit Finalize Validation (WL01)  */
/**************************************************************************/

CREATE TRIGGER [dbo].[ntrKitHeaderUpdate]
ON  [dbo].[KIT] FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success    int       -- Populated by calls to stored procedures - was the proc successful?
         , @n_err        int       -- Error number returned by stored procedure or this trigger
         , @n_err2       int       -- For Additional Error Detection
         , @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
         , @n_continue   int                 
         , @n_starttcnt  int       -- Holds the current transaction count
         , @c_preprocess NVARCHAR(250) -- preprocess
         , @c_pstprocess NVARCHAR(250) -- post process
         , @n_cnt        int                  
         , @c_PostFinalizeKitSP     NVARCHAR(10)   ---(Wan01) 
         , @c_PreFinalizeKitSP      NVARCHAR(10)   ---(NJOW01) 


   DECLARE @c_KitKey NVARCHAR(10)
         , @c_Storerkey NVARCHAR(20)
         , @c_Status NVARCHAR(10)

   /*CS01 Start*/
    DECLARE @c_Lottable01Label   NVARCHAR(20),
            @c_Lottable02Label   NVARCHAR(20),
            @c_Lottable03Label   NVARCHAR(20),  
            @c_Lottable04Label   NVARCHAR(20),  
            @c_DOCType           NVARCHAR(1),
            @dt_lottable04_Find  Datetime,
            @c_susr2             NVARCHAR(18),
            @c_KitLineNumber     NVARCHAR(5),
            @c_Lottable01        NVARCHAR(18),            
            @c_Lottable02        NVARCHAR(18),            
            @c_Lottable03        NVARCHAR(18),            
            @dt_Lottable04       DATETIME ,               
            @dt_Lottable05       DATETIME,
            @c_Lottable06        NVARCHAR(30),
            @n_LottableRules     INT,
            @c_GetKitKey         NVARCHAR(10),
            @c_GetStorerKey      NVARCHAR(15), 
            @c_sku               NVARCHAR(20),
            @c_GetStatus         NVARCHAR(10) 
      
   --NJOW02          
   DECLARE @c_SQL  NVARCHAR(2000)
          ,@c_KitSplitDoneToFinalize NVARCHAR(30)
          ,@c_SPName NVARCHAR(50)
          ,@c_Facility NVARCHAR(5)

   --WL01
   DECLARE @c_GetFacility NVARCHAR(5), @c_GetAuthority NVARCHAR(30)
                 
   /*CS01 End*/
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4 
   END
   
   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --MC03
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --MC03

   -- tlting01
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
                 WHERE INSERTED.KitKey = DELETED.KitKey
                 AND ( INSERTED.[status] < '9' OR DELETED.[status] < '9' ) ) 
         AND (@n_continue = 1 or @n_continue=2)
         AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE KIT with (ROWLOCK)
      SET EditDate = GETDATE(),
          EditWho  = SUSER_SNAME(),
          TrafficCop = NULL
      FROM KIT , INSERTED (NOLOCK)
      WHERE KIT.KitKey = INSERTED.KitKey
      AND   KIT.[status] < '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KIT. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4 
   END
      /* #INCLUDE <TRTHU1.SQL> */     
   -- 10.8.99 WALLY
   -- set reasoncode as mandatory field
   IF @n_continue = 1 or @n_continue=2
   BEGIN 
      DECLARE @c_reasoncode NVARCHAR(10)
      SELECT  @c_reasoncode = INSERTED.reasoncode 
      FROM  INSERTED (NOLOCK), DELETED (NOLOCK)
      WHERE INSERTED.KitKey = DELETED.KitKey
   
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) IS NULL  or dbo.fnc_LTrim(dbo.fnc_RTrim(@c_reasoncode)) = ''
      BEGIN
         SELECT @n_continue = 3, @n_err = 50000
         SELECT @c_errmsg = 'VALIDATION ERROR: Reason Code Required.(ntrKitHeaderUpdate)'
      END
   END

   -- Changed by Vicky on 26-Sept-2006
   -- Get Status from Inserted
   SELECT @c_KitKey = K.KitKey,
          @c_Storerkey = K.Storerkey,
          @c_Status = INSERTED.Status, 
          @c_GetFacility = K.Facility --WL01 
   FROM   KIT K (NOLOCK), INSERTED,  DELETED
   WHERE K.KitKey = INSERTED.KitKey
   AND   INSERTED.KitKey = DELETED.KitKey

   IF EXISTS (SELECT 1 
              FROM INSERTED
              JOIN DELETED ON (INSERTED.KitKey = DELETED.KitKey)  
              WHERE INSERTED.Status ='9'
              AND DELETED.Status <> '9')
   BEGIN   
   --Extended Validation
   --WL01 Start
      IF @n_continue = 1 or @n_continue = 2 
      BEGIN
         EXEC nspGetRight   
               @c_GetFacility                  -- facility  
            ,  @c_Storerkey                    -- Storerkey  
            ,  NULL                            -- Sku  
            ,  'KitExtendedValidation'         -- Configkey  
            ,  @b_Success           OUTPUT   
            ,  @c_GetAuthority      OUTPUT   
            ,  @n_Err               OUTPUT   
            ,  @c_ErrMsg            OUTPUT  

         IF @b_success <> 1  
         BEGIN 
            SET @n_Continue= 3 
            SET @b_Success = 0
            SET @n_err  = 69700
            SET @c_errmsg = 'Execute ntrKitHeaderUpdate Failed.' + CHAR(13)
                          + '(' + @c_errmsg + ')'
         END 

         IF @c_GetAuthority <> ''
         BEGIN
            EXEC isp_KIT_ExtendedValidation
              @c_KITKey              = @c_KitKey
            , @c_KITValidationRules  = @c_GetAuthority
            , @b_Success             = @b_Success  OUTPUT
            , @c_ErrMsg              = @c_ErrMsg   OUTPUT
            , @c_KITLineNumber       = ''

            IF @b_success <> 1  
            BEGIN 
               SET @n_Continue= 3 
               SET @b_Success = 0
               SET @n_err  = 69700
               SET @c_errmsg = 'Execute ntrKitHeaderUpdate Failed.' + CHAR(13)
                             + '(' + @c_errmsg + ')'
            END 
         END --@c_authority
      END
   END

   --(NJOW01) - START 
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM INSERTED
                 JOIN DELETED ON (INSERTED.KitKey = DELETED.KitKey)  
                 WHERE INSERTED.Status ='9'
                 AND DELETED.Status <> '9')
      BEGIN     
         SET @b_Success = 0
         SET @c_PreFinalizeKitSP = ''
         EXEC nspGetRight  
               @c_Facility  = @c_GetFacility --NULL  (WL01)
             , @c_StorerKey = @c_StorerKey 
             , @c_sku       = NULL
             , @c_ConfigKey = 'PreFinalizeKitSP'  
             , @b_Success   = @b_Success           OUTPUT  
             , @c_authority = @c_PreFinalizeKitSP  OUTPUT   
             , @n_err       = @n_err               OUTPUT   
             , @c_errmsg    = @c_errmsg            OUTPUT  

         IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreFinalizeKitSP AND TYPE = 'P')
         BEGIN
            SET @b_Success = 0  
            EXECUTE dbo.ispPreFinalizeKitWrapper 
                    @c_KitKey             = @c_KitKey
                  , @c_PreFinalizeKitSP  = @c_PreFinalizeKitSP
                  , @b_Success = @b_Success     OUTPUT  
                  , @n_Err     = @n_err         OUTPUT   
                  , @c_ErrMsg  = @c_errmsg      OUTPUT  
                  , @b_debug   = 0 

            IF @n_err <> 0  
            BEGIN 
               SET @n_Continue= 3 
               SET @b_Success = 0
               SET @n_err  = 69700
               SET @c_errmsg = 'Execute ntrKitHeaderUpdate Failed.'
                             + '(' + @c_errmsg + ')'
            END 
         END 
      END
   END
   --(NJOW01) - End

   /*CS01 Start*/
    --declare @b_debug nvarchar(1)

    --SET @b_debug='1'
    SET @c_GetStatus = ''
    SET @c_GetStorerkey = ''
    SET @c_GetKitKey = ''
    SET @c_lottable06 = ''

    SELECT   @c_GetKitKey = K.KitKey,
             @c_GetStorerkey = K.Storerkey,
				 @c_GetStatus = INSERTED.Status 
      FROM   KIT K (NOLOCK), INSERTED,  DELETED
      WHERE K.KitKey = INSERTED.KitKey
      AND   INSERTED.KitKey = DELETED.KitKey
		AND   INSERTED.Status = '9'
      AND   DELETED.Status <> '9' 


   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)  
              WHERE StorerKey = @c_GetStorerkey  
              AND   ConfigKey = 'KitFinalizeLottableRules'  
              AND   sValue = '1') 
   BEGIN 
     SET @n_LottableRules = 1  
   END
   ELSE
   BEGIN  
     SET @n_LottableRules = 0  
   END

   IF @n_LottableRules = 1 AND @c_GetStatus = '9' AND @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT
             Storerkey
            ,Sku
            ,KitLineNumber
      FROM KITDETAIL WITH (NOLOCK)
      WHERE Kitkey = @c_GetKitKey
      AND TYPE ='T'
      -- AND   KITLineNumber = CASE WHEN ISNULL(RTRIM(@c_KitLineNumber),'') = '' THEN ReceiptLineNumber ELSE @c_ReceiptLineNumber END
      GROUP BY storerkey,sku,kitlinenumber
      ORDER BY KitLineNumber
      
      OPEN CUR_RD
      
      FETCH NEXT FROM CUR_RD INTO @c_GetStorerkey
                                 ,@c_Sku
                                 ,@c_KitLineNumber
                            
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
      
            --SET @c_Sku = ''
      
            --SELECT @c_Sku = SKU
            --FROM KITDETAIL KTDET (NOLOCK)
            -- WHERE KTDET.KITkey  = @c_Kitkey
            -- AND KTDET.KitLineNumber = @c_KitLineNumber
            -- AND TYPE ='T'
      
            SELECT @c_Lottable01Label = ISNULL(RTRIM(Lottable01Label),''),
                   @c_Lottable02Label = ISNULL(RTRIM(Lottable02Label),''),
                   @c_Lottable03Label = ISNULL(RTRIM(Lottable03Label),''),  
                   @c_Lottable04Label = ISNULL(RTRIM(Lottable04Label),''),
                   @c_susr2           = ISNULL(RTRIM(Susr2),'')  
            FROM SKU (NOLOCK)
            WHERE Storerkey = @c_GetStorerkey
            AND Sku = @c_Sku 
      
         IF @c_Lottable04Label = 'EXP-DATE'  
         BEGIN
            SELECT @n_continue = 1
         END
         ELSE
         BEGIN
            SET @n_continue = 3
           
      
            IF @c_Lottable04Label <> 'EXP-DATE'  
            BEGIN
               SET @n_err = 69706
               SET @c_Errmsg = CONVERT ( NVARCHAR(5), @n_err) + ' Invalid Lottable04Label Setup.  (ntrKitHeaderUpdate)'
            END
           -- GOTO QUIT
         END
      END
    
      SELECT @dt_lottable04_Find  = Lottable04
      FROM KITDETAIL KTDET WITH (NOLOCK)
      WHERE KTDET.KITkey = @c_GetKitKey
      AND KTDET.KitLineNumber = @c_KitLineNumber
      AND Type='T'  

      SET @c_lottable06 = convert(nvarchar(10),(@dt_lottable04_Find - CAST(@c_susr2 as int)) ,111)

      UPDATE KITDETAIL WITH (ROWLOCK)
      SET Lottable06 = ISNULL(@c_lottable06,'')
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,Trafficcop = NULL
      WHERE KITkey = @c_GetKitKey
      AND KitLineNumber = @c_KitLineNumber
      AND Type='T'  

      -- if @b_debug='1'
      -- BEGIN
      --    select *
      --    from kitdetail (nolock)
      --    WHERE KITkey = @c_GetKitKey
      --  AND KitLineNumber = @c_KitLineNumber
      --  AND Type='T'   
      --END

      SET @n_err = @@ERROR

      IF @n_Err <> 0 
      BEGIN
         SET @n_continue = 3
         SET @n_Err   = 69707
         SET @c_errmsg= 'NSQL'+CONVERT(char(5),@n_err)+': UPDATE KITDETAIL Fail. (ntrKitHeaderUpdate)'

         --GOTO QUIT
      END

      FETCH NEXT FROM CUR_RD INTO @c_GetStorerkey
                                 ,@c_Sku
                                 ,@c_KitLineNumber
      END
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END
   /*CS01 End*/
   
   --NJOW02
   IF @n_continue = 1 or @n_continue=2
   BEGIN   	          
      DECLARE CUR_KITFINALIZE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT I.kitKey, I.Storerkey, I.Facility
         FROM INSERTED I (NOLOCK)    	
         JOIN DELETED D (NOLOCK) ON I.Kitkey = D.Kitkey
         WHERE D.Status <> I.Status 
         AND I.Status = '9'
         ORDER BY I.Kitkey
      
      OPEN CUR_KITFINALIZE  
      FETCH NEXT FROM CUR_KITFINALIZE INTO @c_Kitkey, @c_Storerkey, @c_Facility
      
      WHILE @@FETCH_STATUS = 0  AND @n_continue IN(1,2)
      BEGIN         	
       	 SELECT @c_KitSplitDoneToFinalize = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'KitSplitDoneToFinalize') 
       	 
       	 IF @c_KitSplitDoneToFinalize = '1'
       	    SET @c_SPName = 'isp_KitSplitDoneToFinalize'
       	 ELSE 
       	    SET @c_SPName = @c_KitSplitDoneToFinalize       	 
       	 
       	 IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = @c_SPName AND type = 'P')          
         BEGIN          
              SET @c_SQL = 'EXEC ' + @c_SPName + ' @c_KitKey, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT, @n_Continue OUTPUT '          
              EXEC sp_executesql @c_SQL,          
                   N'@c_KitKey NVARCHAR(10), @b_Success Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT, @n_Continue INT OUTPUT',
                   @c_KitKey,          
                   @b_Success OUTPUT,          
                   @n_Err OUTPUT,          
                   @c_ErrMsg OUTPUT,
                   @n_continue OUTPUT
                                      
               IF @b_Success <> 1     
               BEGIN    
               	  SELECT @n_continue = 3
               END     
         END          
      	      	
         FETCH NEXT FROM CUR_KITFINALIZE INTO @c_Kitkey, @c_Storerkey, @c_Facility          
      END
      CLOSE CUR_KITFINALIZE   	
      DEALLOCATE CUR_KITFINALIZE   	
   END
      
   -- Added By SHONG 
   -- 08th Nov 2000
   -- Begin
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      UPDATE KITDETAIL with (ROWLOCK)
       SET Status = '9',
           EditDate = GETDATE(),       --tlting
           EditWho = SUSER_SNAME()
      FROM KITDETAIL, INSERTED (NOLOCK), DELETED (NOLOCK)
      WHERE INSERTED.KitKey = DELETED.KitKey
      AND   INSERTED.KitKey = KITDETAIL.KitKey
      AND   INSERTED.Status = '9'
      AND   DELETED.Status <> '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KITDETAIL. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   -- End 08th Nov 2000
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      UPDATE KIT with (ROWLOCK)
      SET Status = '0',
        EditDate = GETDATE(),   --tlting
        EditWho = SUSER_SNAME()
      FROM KIT,
      INSERTED (NOLOCK), DELETED (NOLOCK)
      WHERE KIT.KitKey = INSERTED.KitKey
      AND INSERTED.KitKey = DELETED.KitKey
      AND DELETED.Status = '9'    
      AND EXISTS( SELECT 1 FROM KITDETAIL (NOLOCK) WHERE KitDetail.KITKEY = KIT.KitKey
                    AND KitDetail.Status <> '9')
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69702   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KIT. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      UPDATE KIT with (ROWLOCK)
      SET Status = '9',
          EditDate = GETDATE(),   --tlting
          EditWho = SUSER_SNAME()
      FROM KIT, INSERTED (NOLOCK), DELETED (NOLOCK)
      WHERE KIT.KitKey = INSERTED.KitKey
      AND INSERTED.KitKey = DELETED.KitKey
      AND NOT EXISTS( SELECT 1 FROM KITDETAIL (NOLOCK) WHERE KitDetail.KITKEY = KIT.KitKey
                    AND KitDetail.Status <> '9' AND KITDETAIL.Type = 'T')
      AND EXISTS (SELECT 1 FROM KITDETAIL (NOLOCK) WHERE KitDetail.KITKEY = KIT.KitKey AND KITDETAIL.Type = 'T')  --WANYT SOS#82310: Error 34
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69703   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KIT. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE KIT
      SET EditDate = GETDATE(),
          EditWho = SUSER_SNAME(),
          TrafficCop = NULL                           -- tlting01
      FROM KIT (NOLOCK), INSERTED (NOLOCK)
      WHERE KIT.KitKey = INSERTED.KitKey
      AND   KIT.[status] in ( '9' , 'CANC' )          -- tlting01

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69701   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KIT. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   -- Added By CCLAW
   -- FBR039(IDSHK) - 08/08/2001 : Status=3 after first printing.
   -- Begin
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      UPDATE KITDETAIL
      SET Status = '3'
      FROM KITDETAIL, INSERTED, DELETED
      WHERE INSERTED.KitKey = DELETED.KitKey
      AND   INSERTED.KitKey = KITDETAIL.KitKey
      AND   INSERTED.Status = '3'
      AND   DELETED.Status < '3'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=69705   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table KITDETAIL. (ntrKitHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END
   -- End CCLAW FBR039 08/08/2001

   IF @n_continue = 1 or @n_continue = 2 
   BEGIN                           
      -- Generate Interface File Here................
      IF @c_Status = '9'
      BEGIN
      -- 24 Sept 2004 YTWan - FBR_JAMO010-Outbound-Kitting Confirmation - START
      IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_Storerkey
                    AND ConfigKey = 'JAMOKITCFMITF' AND sValue = '1' )
       BEGIN
            EXEC ispGenTransmitLog2 'JAMOKITCFM', @c_KitKey , '', @c_Storerkey , ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

          IF @b_success <> 1
          BEGIN
             SELECT @n_continue = 3
          END
      END -- Valid StorerConfig,  OrderType
         -- 24 Sept 2004 YTWan - FBR_JAMO010-Outbound-Kitting Confirmation - END
       -- Added By Vicky on 8th-July-2005 - Start
       IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_Storerkey
                       AND ConfigKey = 'KITLOG' AND sValue = '1' )
       BEGIN
           EXEC ispGenTransmitLog3 'KITLOG', @c_KitKey, '', @c_Storerkey, '' 
              , @b_success OUTPUT
              , @n_err OUTPUT
              , @c_errmsg OUTPUT

           IF @b_success <> 1
           BEGIN
             SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63811   -- should be set to the sql errmessage but i don't know how to do so.
             SELECT @c_errmsg = 'nsql' + CONVERT(CHAR(5),@n_err) + ': Unable To Obtain LogKey. (ntrKitHeaderUpdate)' + ' ( ' + ' sqlsvr message=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
           END
        END -- If exists kitlog -- Added By Vicky on 8th-July-2005 - End
     END -- End Status = '9'
   END -- ENd continue = 1 or 2


   --(Wan01) - START 
   IF @n_continue = 1 or @n_continue = 2 
   BEGIN
      IF EXISTS (SELECT 1 
                 FROM INSERTED
                 JOIN DELETED ON (INSERTED.KitKey = DELETED.KitKey)  
                 WHERE INSERTED.Status ='9'
                 AND DELETED.Status <> '9')
      BEGIN
         SET @b_Success = 0
         SET @c_PostFinalizeKitSP = ''
         EXEC nspGetRight  
               @c_Facility  = @c_GetFacility --WL01 
             , @c_StorerKey = @c_StorerKey 
             , @c_sku       = NULL
             , @c_ConfigKey = 'PostFinalizeKitSP'  
             , @b_Success   = @b_Success           OUTPUT  
             , @c_authority = @c_PostFinalizeKitSP OUTPUT   
             , @n_err       = @n_err               OUTPUT   
             , @c_errmsg    = @c_errmsg            OUTPUT  

         IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeKitSP AND TYPE = 'P')
         BEGIN
            SET @b_Success = 0  
            EXECUTE dbo.ispPostFinalizeKitWrapper 
                    @c_KitKey             = @c_KitKey
                  , @c_PostFinalizeKitSP  = @c_PostFinalizeKitSP
                  , @b_Success = @b_Success     OUTPUT  
                  , @n_Err     = @n_err         OUTPUT   
                  , @c_ErrMsg  = @c_errmsg      OUTPUT  
                  , @b_debug   = 0 

            IF @n_err <> 0  
            BEGIN 
               SET @n_Continue= 3 
               SET @b_Success = 0
               SET @n_err  = 69706
               SET @c_errmsg = 'Execute ntrKitHeaderUpdate Failed.'
                             + '(' + @c_errmsg + ')'
            END 
         END 
      END
   END
   --(Wan01) - End

   -- (MC03) - S  
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (Start)   */  
   /********************************************************/  
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN        
      DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
      SELECT INS.KITKey
           , INS.StorerKey
      FROM   INSERTED INS 
      JOIN   ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE  ITC.SourceTable = 'KIT'  
      AND    ITC.sValue      = '1'       

      OPEN Cur_TriggerPoints  
      FETCH NEXT FROM Cur_TriggerPoints INTO @c_KitKey, @c_Storerkey

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         EXECUTE dbo.isp_ITF_ntrKIT 
                  @c_TriggerName    = 'ntrKitHeaderUpdate'
                , @c_SourceTable    = 'KIT'  
                , @c_KitKey         = @c_KitKey  
                , @b_ColumnsUpdated = @b_ColumnsUpdated    
                , @b_Success        = @b_Success   OUTPUT  
                , @n_err            = @n_err       OUTPUT  
                , @c_errmsg         = @c_errmsg    OUTPUT  

         FETCH NEXT FROM Cur_TriggerPoints INTO @c_KitKey, @c_Storerkey
      END -- WHILE @@FETCH_STATUS <> -1  
      CLOSE Cur_TriggerPoints  
      DEALLOCATE Cur_TriggerPoints  
   END -- IF @n_continue = 1 OR @n_continue = 2   
   /********************************************************/  
   /* Interface Trigger Points Calling Process - (End)     */  
   /********************************************************/  
   -- (MC03) - E

      /* #INCLUDE <TRTHU2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'ntrKitHeaderUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
    END
    ELSE
    BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       RETURN
    END
END



GO