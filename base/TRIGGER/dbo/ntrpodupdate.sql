SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Trigger:  ntrPODUpdate                                               */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  Trigger point upon any Update SKUxLOC                      */    
/*                                                                      */    
/* Input Parameters:                                                    */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: When records updated                                      */    
/*                                                                      */    
/* PVCS Version: 1.2                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 03-Jan-2003  SHONG     1.0   Check FinalizeFlag when insert into     */    
/*                              transmitlog table.                      */    
/* 07-Apr-2004  SHONG     1.0   To prevent user to enter unreasonable   */    
/*                              Date                                    */    
/* 22-Jul-2004  SHONG     1.0   Convert SELECT MIN to Cursor Loop       */     
/* 15-Sep-2005  Vicky     1.0   Take Out Fetch Next = 0 from Trigantic  */    
/*                              record insertion checking               */      
/* 14-Sep-2005  Vicky     1.0   SOS#39993 - Add in insertion of Status  */    
/*                              as Key2 in Triganticlog table           */     
/* 17-Apr-2006  Shong     1.0   Add Default Getdate() to prevent ANSI   */    
/*                              Warning Message (SHONG_20060417)        */    
/*                              Immediately return if Update ArchiveCop */     
/* 14-Feb-2007  James     1.0   Check if storerkey is null, assigned    */    
/*                              one to it                               */    
/* 11-Mar-2009  Yokebeen  1.1   Added Generic Trigger point for POD.    */    
/*                              ConfigKey = "PODLOG" must always be ON. */    
/*                              ConfigKey = "ALLPODLOG" is to request   */    
/*                              yes/no to trigger records upon each     */    
/*                              status update. No is being defaulted.   */    
/*                              - (YokeBeen01)                          */    
/* 11-Sept-2009 TLTING     1.2  SOS146709 Set Trigantic intf mandatory  */    
/*                             - Update Editwho&EditDate                */    
/*                              (tlting01)                              */    
/* 03-Jan-2012  TLTING02   1.3  SOS231886 ActualDeliveryDate not null   */    
/* 31-May-2012  TLTING01   1.4  DM Integrity issue - Update editdate for*/    
/*                              B4 trafficCop check                     */    
/* 09-Apr-2013  Shong      1.5  Replace GetKey with isp_GetTriganticKey */  
/*                              to reduce blocking                      */  
/* 22-May-2013  TLTING01   1.6  Call nspg_getkey to gen TriganticKey    */  
/* 28-Oct-2013  TLTING     1.7  Review Editdate column update           */  
/* 14-May-2014  YTWan      1.8  SOS#305034 - FBR - POD Extended         */  
/*                              Validation Enhancement (Wan01)          */  
/* 12-Aug-2014  MCTang     1.9  New Interface Trigger Points (MC01)     */  
/* 09-Sep-2014  TLTING     2.0  Doc Status Tracking Log TLTING03        */  
/* 11-May-2015  TLTING     2.1  Disable Trigantics                      */   
/* 18-Nov-2021  Wan01      2.2  WMS-18336 - MYSûSBUXMûDefault value in  */  
/*                              POD Entry column upon update POD Status */  
/* 18-Nov-2021  Wan01      2.3  DevOps Combine Script.                  */ 
/* 18-Nov-2021  TLTING04   2.4  Disable STSORDERS insert 4Docstatustrack*/   
/* 07-Sep-2022  YTKuek     2.5  GVT Interface Trigger Point (YT01)      */
/************************************************************************/    
-- Added by YokeBeen on 14-Jan-2003 (YokeBeen01 - SOS#FBR8465)    
CREATE   TRIGGER [dbo].[ntrPODUpdate]    
ON  [dbo].[POD]    
FOR UPDATE    
AS    
BEGIN    -- tlting01    
IF @@ROWCOUNT = 0    
BEGIN    
   RETURN    
END    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   DECLARE    
           @b_Success               int         -- Populated by calls to stored procedures - was the proc successful?    
         , @n_err                   int         -- Error number returned by stored procedure or this trigger    
         , @n_err2                  int         -- For Additional Error Detection    
         , @c_errmsg                NVARCHAR(250)   -- Error message returned by stored procedure or this trigger    
         , @n_continue              int                     
         , @n_starttcnt             int         -- Holds the current transaction count    
         , @c_preprocess            NVARCHAR(250)   -- preprocess    
         , @c_pstprocess            NVARCHAR(250)   -- post process    
         , @n_cnt                   int       
         , @c_ReturnRefNo           NVARCHAR(15)     
         , @c_authority_AllPODLog   NVARCHAR(1)     -- (YokeBeen01)     
         , @c_authority_PODLog      NVARCHAR(1)     -- (YokeBeen01)     
         , @c_XStorerKey            NVARCHAR(15) -- (YokeBeen01)     
    
   --(Wan01) - START  
   DECLARE @c_StorerKey             NVARCHAR(15)  
         , @c_MBOLKey               NVARCHAR(10)    
         , @c_MBOLLineNumber        NVARCHAR(5)      
         , @c_PODValidationRules    NVARCHAR(30)   
         , @c_SQL                   NVARCHAR(MAX)    
   --(Wan01) - END  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT    
     /* #INCLUDE <TRPOHA1.SQL> */    
    
   --(Wan01) - START  
   SET @c_StorerKey = ''  
   SET @c_MBOLKey   = ''  
   SET @c_MBOLLineNumber = ''     
   SET @c_PODValidationRules = ''   
   SET @c_SQL       = ''  
   --(Wan01) - END  
  
   -- (SHONG_20060417)    
   IF UPDATE(ArchiveCop)     
   BEGIN    
      SELECT @n_continue = 4     
      RETURN     
   END    
   -- (SHONG_20060417)    
     
         
   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --MC01  
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --MC01  
  
   -- tlting01    
   -- Added BY SHONG 08-JAN-2003    
   IF ( @n_Continue = 1 OR @n_Continue = 2 ) AND NOT UPDATE(EditDate)  
   BEGIN    
      UPDATE POD WITH (ROWLOCK)     
         SET EditWho = sUser_sName(),    
             EditDate = GetDate(),     
             TrafficCop = NULL    
        FROM INSERTED     
       WHERE INSERTED.MBOLKey = POD.MBOLKey    
         AND INSERTED.MBOLLineNumber = POD.MBOLLineNumber    
   END    
   -- End    
       
   -- Added before TrafficCop    
   -- To Make sure it's still trigger the Transmitflag    
   -- Added By SHONG    
   -- begin    
   DECLARE @cOrdKey NVARCHAR(10)    
   --        @c_TriganticLogkey NVARCHAR(10)    
   --tlting01    
   --IF EXISTS( SELECT 1 FROM ORDERS WITH (NOLOCK)    
   --             JOIN StorerConfig WITH (NOLOCK) ON (StorerConfig.StorerKey = ORDERS.StorerKey)    
   --             JOIN INSERTED WITH (NOLOCK) ON (INSERTED.OrderKey = ORDERS.OrderKey)     
   --            WHERE ConfigKey = 'TIPS_POD' AND sValue = '1')    
   --BEGIN    
      SELECT @cOrdKey = SPACE(10)    
          
      DECLARE C_PODUpdOrdKey  CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR       
         SELECT INSERTED.OrderKey, ORDERS.StorerKey    
         FROM   INSERTED     
         JOIN   DELETED ON (INSERTED.OrderKey = DELETED.OrderKey)     
         JOIN   ORDERS WITH (NOLOCK) ON (INSERTED.OrderKey = ORDERS.OrderKey)     
         WHERE  (INSERTED.Status <> DELETED.Status    
                  OR INSERTED.ActualDeliveryDate <> DELETED.ActualDeliveryDate    
                  OR INSERTED.PodReceivedDate <> DELETED.PodReceivedDate)    
         ORDER BY INSERTED.OrderKey    
          
      OPEN C_PODUpdOrdKey    
    
      WHILE 1=1 -- Modified - Take Out Fetch Next = 0 from here    
      BEGIN    
         FETCH NEXT FROM C_PODUpdOrdKey INTO @cOrdKey, @c_StorerKey    
       
         IF @@FETCH_STATUS = -1    
            BREAK    
           
         -- TLTING03  
--         IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)     
--                         WHERE TableName = 'STSORDERS' AND DocumentNo = @cOrdKey AND DocStatus = '9')      
--         BEGIN    
--            EXEC ispGenDocStatusLog 'STSORDERS', @c_StorerKey, @cOrdKey, '', '', '9'    
--                           , @b_success OUTPUT    
--                           , @n_err OUTPUT    
--                           , @c_errmsg OUTPUT    
--            IF NOT @b_success=1    
--            BEGIN    
--               SELECT @n_continue=3    
--            END        
--         END  
                

      END    
      CLOSE C_PODUpdOrdKey    
      DEALLOCATE C_PODUpdOrdKey    
   --END    
   -- end         
    
   -- To Make sure it's still trigger the Trianmitflag     
   -- Added By SHONG on 19-DEC-2003 for Trigantic POD Export    
   -- begin    
       
   -- tlting01    
      IF UPDATE(PODDef08) OR UPDATE(PODDef04)    
      BEGIN    
         SELECT @cOrdKey = SPACE(10)    
          
         DECLARE C_PODUpdOrdKey_ONE  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
         SELECT INSERTED.OrderKey, INSERTED.Storerkey    
           FROM INSERTED     
           JOIN DELETED ON (INSERTED.OrderKey = DELETED.OrderKey)     
          WHERE ( INSERTED.PODDef08 <> ISNULL(DELETED.PODDef08, '') OR    
                  INSERTED.PODDef04 <> ISNULL(DELETED.PODDef04, '') )    
          ORDER BY INSERTED.OrderKey    
          
         OPEN C_PODUpdOrdKey_ONE    
    
         WHILE 1=1     
         BEGIN    
            FETCH NEXT FROM C_PODUpdOrdKey_ONE INTO @cOrdKey, @c_StorerKey    
          
            IF @@FETCH_STATUS = -1    
               BREAK    
  
            -- TLTING  
            IF NOT EXISTS (SELECT 1 FROM DocStatusTrack WITH (NOLOCK)     
                            WHERE TableName = 'STSPOD' AND DocumentNo = @cOrdKey )    
            BEGIN    
               EXEC ispGenDocStatusLog 'STSPOD', @c_StorerKey, @cOrdKey, '', '', '9'    
                              , @b_success OUTPUT    
                              , @n_err OUTPUT    
                              , @c_errmsg OUTPUT    
       
               IF NOT @b_success=1    
               BEGIN     
                  SELECT @n_continue=3    
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62905       
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                   + ': INSERT DocStatusTrack Failed (ntrPODUpdate)'     
                                   + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
                    
               END              
              
            END  
                      

         END    
         CLOSE C_PODUpdOrdKey_ONE    
         DEALLOCATE C_PODUpdOrdKey_ONE    
      END     
--   END    
    
   --         
   -- SOS# 9212 Remove Tab Order in Form and make the Checking in Backend    
   -- Added by SHONG 07-Jan-2003    
   IF UPDATE(TrafficCop)    
   BEGIN    
      SELECT @n_continue = 4     
   END    
    
   IF @n_continue IN (1,2)  
   BEGIN    
      IF EXISTS (SELECT 1 FROM DELETED d    
                 JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey    
                 JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue    
                 WHERE  s.configkey = 'PODTrigger_SP')    
      BEGIN    
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL    
            DROP TABLE #INSERTED    
    
         SELECT *    
         INTO #INSERTED    
         FROM INSERTED    
    
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL    
            DROP TABLE #DELETED    
    
         SELECT *    
         INTO #DELETED    
         FROM DELETED    
    
         EXECUTE dbo.isp_PODTrigger_Wrapper    
              'UPDATE'  --@c_Action    
            , @b_Success  OUTPUT    
            , @n_Err      OUTPUT    
            , @c_ErrMsg   OUTPUT    
    
         IF @b_success <> 1    
         BEGIN    
            SELECT @n_continue = 3    
                  ,@c_errmsg = 'ntrPODUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))    
         END    
    
         IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL    
            DROP TABLE #INSERTED    
    
         IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL    
            DROP TABLE #DELETED    
      END    
   END    
   -- Added By SHONG on 07-April-2004    
   -- To prevent user to enter unreasonable Date     
   DECLARE @d_ActualDeliveryDate datetime,    
           @d_FullRejectDate     datetime,    
           @d_PartialRejectDate  datetime    
    
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
   -- (SHONG_20060417)    
      SELECT @d_ActualDeliveryDate = MAX(ISNULL(ActualDeliveryDate, GETDATE())),    
             @d_FullRejectDate    = MAX(ISNULL(FullRejectDate, GETDATE())),    
             @d_PartialRejectDate = MAX(ISNULL(PartialRejectDate, GETDATE()))    
      FROM INSERTED     
    
   -- (SHONG_20060417)    
      IF DateDiff(day, GetDate(), @d_ActualDeliveryDate) > 7     
      BEGIN    
         SELECT @n_continue=3     
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62910      
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': Update Failed! Actual Delivery Date Cannot Greater Then 7 days (ntrPODUpdate)'     
      END    
      ELSE IF DateDiff(day, GetDate(), @d_FullRejectDate) > 7     
      BEGIN    
         SELECT @n_continue=3     
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62910      
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': Update Failed! Full Reject Date Cannot Greater Then 7 days (ntrPODUpdate)'     
      END     
      ELSE IF DateDiff(day, GetDate(), @d_PartialRejectDate) > 7    
      BEGIN    
         SELECT @n_continue=3     
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62910     
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': Update Failed! Partial Reject Date Cannot Greater Then 7 days (ntrPODUpdate)'     
      END     
   END     
       
    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN     
      IF EXISTS ( SELECT 1     
                    FROM DELETED     
                    JOIN ORDERS WITH (NOLOCK) ON (DELETED.OrderKey = ORDERS.OrderKey)     
                   WHERE DELETED.FinalizeFlag = 'Y'    
                     AND ORDERS.SpecialHandling <> 'Y' )    
      BEGIN    
         SELECT @n_continue=3    
         SELECT @n_err=72900    
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': UPDATE Rejected. POD.FinalizeFlag = ''YES''. (ntrPODUpdate)'    
      END    
   END    
   -- End Added SOS# 9212    
       
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
      -- Check the existence of Configkey, and Svalue = '1'          
      IF EXISTS (SELECT 1 FROM INSERTED WITH (NOLOCK)    
                   JOIN ORDERS WITH (NOLOCK) ON (INSERTED.Orderkey = ORDERS.Orderkey)    
                   JOIN STORERCONFIG WITH (NOLOCK) ON (ORDERS.Consigneekey = STORERCONFIG.Storerkey    
                                                   AND STORERCONFIG.Configkey = 'ULVPODRET'    
                                                   AND STORERCONFIG.SValue = '1')    
                  WHERE INSERTED.Status in ('1', '2', '3')  )    
      BEGIN    
       -- make sure the field ReturnRefNo is keyed in     
         SELECT @c_ReturnRefNo = ReturnRefNo from INSERTED WITH (NOLOCK)    
             
         IF dbo.fnc_RTrim(@c_ReturnRefNo) = '' OR dbo.fnc_RTrim(@c_ReturnRefNo) IS NULL    
         BEGIN    
            SELECT @n_Continue = 3    
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64301       
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                             + ': ReturnRefNo is mandatory. (ntrPODUpdate)'     
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
         END                      
             
         IF @n_continue = 1 OR @n_continue = 2    
         BEGIN    
            --the key must exists in Trade Return (Receipt table) with Rectype<> 'NORMAL'.    
            IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK)    
                             JOIN RECEIPT WITH (NOLOCK) ON (RECEIPTDETAIL.Receiptkey = RECEIPT.Receiptkey     
                                                        AND RECEIPT.RecType <> 'NORMAL')    
                            WHERE RECEIPTDETAIL.Receiptkey = dbo.fnc_RTrim(@c_ReturnRefNo)    
                              AND RECEIPTDETAIL.FinalizeFlag = 'Y' )    
            BEGIN    
               SELECT @n_continue = 3    
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64310      
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                + ': ReturnRefNo does not exists in Trade Return. (ntrPODUpdate)'     
                                + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
            END    
         END    
      END    
   END    
    
   -- Added by Ricky for validation of status     
   IF @n_continue=1 OR @n_continue=2    
   BEGIN     
      IF EXISTS ( SELECT STATUS FROM INSERTED WITH (NOLOCK)     
                   WHERE FINALIZEFLAG = 'Y'    
                     AND STATUS IN ('0','4') )     
      BEGIN    
         SELECT @n_continue = 3    
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64320       
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                          + ': POD Not Allowed to Finalize, Please Check POD Status. (ntrPODUpdate)'     
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
      END    
   END   
   
   --(Wan01) - START  
   IF @n_Continue = 1 OR @n_Continue = 2    
   BEGIN   
      DECLARE C_POD_Validate CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      SELECT INSERTED.MBOLKey  
            ,INSERTED.MBOLLineNumber  
            ,INSERTED.StorerKey    
        FROM INSERTED  
        JOIN DELETED ON (INSERTED.MBOLKey = DELETED.MBOLKey) AND (INSERTED.MBOLLineNumber = DELETED.MBOLLineNumber)  
        WHERE INSERTED.FinalizeFlag = 'Y' AND DELETED.FinalizeFlag <> 'Y'  
  
      OPEN C_POD_Validate    
      FETCH NEXT FROM C_POD_Validate INTO @c_MBOLKey  
                                        , @c_MBOLLineNumber     
                                        , @c_Storerkey   
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @c_PODValidationRules = SC.sValue  
         FROM STORERCONFIG SC WITH (NOLOCK)  
         JOIN CODELKUP CL     WITH (NOLOCK) ON SC.sValue = CL.Listname  
         WHERE SC.StorerKey = @c_StorerKey  
         AND SC.Configkey = 'PODExtendedValidation'  
  
         IF ISNULL(@c_PODValidationRules,'') <> ''  
         BEGIN  
            EXEC isp_POD_ExtendedValidation @c_MBOLKey           = @c_MBOLKey   
                                          , @c_MBOLLineNumber    = @c_MBOLLineNumber  
                                          , @c_PODValidationRules= @c_PODValidationRules   
                                          , @n_Success           = @b_Success             OUTPUT  
                                          , @c_ErrorMsg          = @c_ErrMsg              OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_err = 64322  
            END  
         END  
         ELSE     
         BEGIN  
            SELECT @c_PODValidationRules = SC.sValue      
            FROM STORERCONFIG SC WITH (NOLOCK)   
            WHERE SC.StorerKey = @c_StorerKey   
            AND SC.Configkey = 'PODExtendedValidation'      
                 
            IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_PODValidationRules) AND type = 'P')            
            BEGIN            
               SET @c_SQL = 'EXEC ' + @c_PODValidationRules + ' @c_MBOLKey, @c_MBOLLineNumber, @b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT '            
                  
               EXEC sp_executesql @c_SQL             
                  , N'@c_MBOLKey NVARCHAR(10), @c_MBOLLineNumber NVARCHAR(5), @nSuccess Int OUTPUT, @n_Err Int OUTPUT, @c_ErrMsg NVARCHAR(250) OUTPUT'             
                  , @c_MBOLKey   
                  , @c_MBOLLineNumber           
                  , @b_Success      OUTPUT             
                  , @n_Err          OUTPUT            
                  , @c_ErrMsg       OUTPUT            
  
               IF @b_Success <> 1       
               BEGIN      
                  SET @n_Continue = 3      
                  SET @n_err = 64324       
               END           
            END    
         END              
  
         FETCH NEXT FROM C_POD_Validate INTO @c_MBOLKey  
                                           , @c_MBOLLineNumber     
                                           , @c_Storerkey   
      END  
      CLOSE C_POD_Validate  
      DEALLOCATE C_POD_Validate  
   END  
   --(Wan01) - END  
  
   -- Added by SHONG for DX POD Interface with OW    
   -- Begin    
   IF @n_Continue = 1 OR @n_Continue = 2    
   BEGIN    
      DECLARE --@c_StorerKey NVARCHAR(15),      --(Wan01)   
              @c_OrderKey  NVARCHAR(10),    
              --@c_MBOLKey   NVARCHAR(10),      --(Wan01)  
              --@c_MBOLLineNumber NVARCHAR(5),  --(Wan01)   
              @c_SourceKey      NVARCHAR(15)       
    
      IF Update(FinalizeFlag)     
      BEGIN    
         SELECT @c_OrderKey = SPACE(10)    
         
         DECLARE C_PODUpdOrdKey_TWO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
          SELECT INSERTED.OrderKey, INSERTED.StorerKey    
            FROM INSERTED    
           WHERE FinalizeFlag = 'Y'    
           ORDER BY INSERTED.OrderKey    
    
         OPEN C_PODUpdOrdKey_TWO    
    
         WHILE 1=1    
         BEGIN    
            FETCH NEXT FROM C_PODUpdOrdKey_TWO INTO @c_OrderKey, @c_StorerKey     
    
            IF @@FETCH_STATUS = -1     
               BREAK    
    
            -- Get Storer Configuration -- One World Interface    
            -- Is One World Interface Turn On?    
--             IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK)    
--                        JOIN ORDERS (NOLOCK) ON (ORDERS.StorerKey = StorerConfig.StorerKey)    
--                        WHERE ORDERS.OrderKey = @c_OrderKey    
--                        AND   ConfigKey = 'OWITF' AND sValue = '1')    
            IF ISNULL(RTRIM(@c_StorerKey),'') = ''     
            BEGIN    
               SELECT @c_StorerKey = StorerKey FROM ORDERS WITH (NOLOCK)     
                WHERE ORDERS.OrderKey = @c_OrderKey    
            END     
    
            IF EXISTS( SELECT 1 FROM StorerConfig WITH (NOLOCK)    
                        WHERE StorerConfig.StorerKey = @c_StorerKey    
                          AND ConfigKey = 'OWITF' AND sValue = '1')    
            BEGIN         
               EXEC ispGenTransmitLog 'OWPOD', @c_OrderKey, '', '', ''    
                  , @b_success OUTPUT    
                  , @n_err OUTPUT    
                  , @c_errmsg OUTPUT    
    
               IF @b_success <> 1    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810       
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                   + ': Unable to obtain Transmitlogkey (ntrPODUpdate)'     
                                   + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               END    
            END -- 'OWITF'    
            -- Start - (YokeBeen01 - SOS# / FBR8465)    
            -- Get Storer Configuration -- ULV PODITF Interface    
            -- Is ULVPODITF Interface Turn On?    
                
            DECLARE @c_authority_ulvitf NVARCHAR(1)    
    
            SELECT @c_StorerKey = StorerKey     
            FROM ORDERS (NOLOCK) WHERE OrderKey = @c_OrderKey    
                
            EXECUTE nspGetRight '',     
                     @c_StorerKey,   -- Storer    
                     '',             -- Sku    
                     'ULVPODITF',    -- ConfigKey    
                     @b_success          output,     
                     @c_authority_ulvitf output,     
                     @n_err              output,     
                     @c_errmsg           output    
    
            IF @c_authority_ulvitf = '1'    
            BEGIN         
               EXEC ispGenTransmitLog2 'ULVPODITF', @c_OrderKey, '', @c_StorerKey, ''    
                  , @b_success OUTPUT    
                  , @n_err OUTPUT    
                  , @c_errmsg OUTPUT    
    
               IF @b_success <> 1    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810       
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                   + ': Unable to obtain Transmitlogkey2 (ntrPODUpdate)'     
                                   + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               END    
            END -- end ULV PODITF Interface    
            -- End - (YokeBeen01 - SOS# / FBR8465)                
         END -- WHILE     
         CLOSE C_PODUpdOrdKey_TWO    
         DEALLOCATE C_PODUpdOrdKey_TWO    
      END     
   END    
   -- End POD Interface     
    
   -- (YokeBeen01) - Start     
   IF @n_continue=1 OR @n_continue=2    
   BEGIN    
      DECLARE @c_XOrderKey       NVARCHAR(10)     
            , @c_XStatus         NVARCHAR(10)     
            , @c_IFinalizeFlag   NVARCHAR(1)     
            , @c_DFinalizeFlag   NVARCHAR(1)     
    
      SET @c_authority_AllPODLog = ''    
      SET @c_authority_PODLog = ''    
    
      SELECT DISTINCT @c_XStorerKey = INSERTED.StorerKey     
        FROM INSERTED WITH (NOLOCK)     
    
      EXECUTE nspGetRight '',     
               @c_XStorerKey,         -- Storer    
               '',                    -- Sku    
               'ALLPODLOG',           -- ConfigKey    
               @b_success             output,     
               @c_authority_AllPODLog output,     
               @n_err                 output,     
               @c_errmsg              output    
    
      IF @b_success <> 1     
      BEGIN    
         SELECT @n_continue = 3, @c_errmsg = 'ntrPODUpdate - Unable to verify ConfigKey ALLPODLOG. '     
      END    
    
      EXECUTE nspGetRight '',     
               @c_XStorerKey,         -- Storer    
               '',                    -- Sku    
               'PODLOG',              -- ConfigKey    
               @b_success             output,     
               @c_authority_PODLog    output,     
               @n_err                 output,     
               @c_errmsg              output    
    
      IF @b_success <> 1     
      BEGIN    
         SELECT @n_continue = 3, @c_errmsg = 'ntrPODUpdate - Unable to verify ConfigKey PODLOG. '    
      END    
    
      IF @n_continue=1 OR @n_continue=2    
      BEGIN    
         DECLARE C_PODGenTriggerPoint CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
         SELECT INSERTED.OrderKey, INSERTED.Status, INSERTED.FinalizeFlag, DELETED.FinalizeFlag,    
                  INSERTED.ActualDeliveryDate      
           FROM INSERTED WITH (NOLOCK)     
           JOIN DELETED WITH (NOLOCK) ON (INSERTED.OrderKey = DELETED.OrderKey)     
          WHERE INSERTED.StorerKey = @c_XStorerKey     
          ORDER BY INSERTED.OrderKey    
    
         OPEN C_PODGenTriggerPoint    
         FETCH NEXT FROM C_PODGenTriggerPoint INTO @c_XOrderKey, @c_XStatus, @c_IFinalizeFlag, @c_DFinalizeFlag      
                        , @d_ActualDeliveryDate     
    
         WHILE 1=1    
         BEGIN    
            IF @@FETCH_STATUS = -1 OR NOT (@n_continue=1 OR @n_continue=2)    
               BREAK    
    
            -- Generic Trigger Point upon FinalizeFlag = 'Y'    
            IF (ISNULL(RTRIM(@c_authority_AllPODLog),'') <> '1') AND     
               (ISNULL(RTRIM(@c_authority_PODLog),'') = '1')     
            BEGIN     
               IF (@c_IFinalizeFlag = 'Y') AND (@c_DFinalizeFlag = 'N')     
               BEGIN     
                      
                  IF @d_ActualDeliveryDate IS NULL OR @d_ActualDeliveryDate = Convert(datetime, '19000101')    
                  BEGIN     
                     SELECT @n_continue=3     
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62919      
                     SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                + ': Update Failed! Actual Delivery Date Cannot be Blank (ntrPODUpdate)'     
                  END    
                  IF @n_continue=1 OR @n_continue=2    
                  BEGIN    
                     EXEC ispGenTransmitLog3 'PODLOG', @c_XOrderKey, @c_XStatus, @c_XStorerKey, ''    
                        , @b_success OUTPUT    
                        , @n_err OUTPUT    
                        , @c_errmsg OUTPUT    
    
                     IF @b_success <> 1    
                     BEGIN    
                        SELECT @n_continue = 3    
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810       
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                         + ': Unable to obtain Transmitlogkey3 (ntrPODUpdate)'     
              + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
                     END    
                  END    
               END -- IF (@c_IFinalizeFlag = 'Y') AND (@c_DFinalizeFlag = 'N')     
            END -- IF @c_authority_AllPODLog <> '1' AND @c_authority_PODLog = '1'     
            ELSE     
            -- Generic Trigger Point upon every Status Change    
            IF ISNULL(RTRIM(@c_authority_AllPODLog),'') = '1' AND     
               ISNULL(RTRIM(@c_authority_PODLog),'') = '1'     
            BEGIN     
               EXEC ispGenTransmitLog3 'PODLOG', @c_XOrderKey, @c_XStatus, @c_XStorerKey, ''    
                  , @b_success OUTPUT    
                  , @n_err OUTPUT    
                  , @c_errmsg OUTPUT    
    
               IF @b_success <> 1    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810       
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))     
                                   + ': Unable to obtain Transmitlogkey3 (ntrPODUpdate)'     
                                   + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               END    
            END -- IF @c_authority_AllPODLog = '1' AND @c_authority_PODLog = '1'     
    
            FETCH NEXT FROM C_PODGenTriggerPoint INTO @c_XOrderKey, @c_XStatus, @c_IFinalizeFlag, @c_DFinalizeFlag      
                           , @d_ActualDeliveryDate     
         END -- WHILE      
         CLOSE C_PODGenTriggerPoint    
         DEALLOCATE C_PODGenTriggerPoint    
      END -- IF @n_continue=1 OR @n_continue=2 -- Cursor Loop    
   END -- IF @n_continue=1 OR @n_continue=2    
   -- (YokeBeen01) - End     
     
   -- (MC01) - S    
   /********************************************************/    
   /* Interface Trigger Points Calling Process - (Start)   */    
   /********************************************************/    
   IF @n_continue = 1 OR @n_continue = 2     
   BEGIN          
      DECLARE Cur_Order_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
      -- Extract values for required variables    
      SELECT DISTINCT INS.Mbolkey  
                    , INS.Mbollinenumber    
                    , INS.StorerKey  
      FROM  INSERTED INS   
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey    
      WHERE ITC.SourceTable = 'POD'    
      AND   ITC.sValue      = '1'    
      --(YT01)-S
      UNION
      SELECT DISTINCT INS.Mbolkey  
                    , INS.Mbollinenumber    
                    , INS.StorerKey  
      FROM  INSERTED INS   
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = 'ALL'
      WHERE ITC.SourceTable = 'POD'    
      AND   ITC.sValue      = '1'   
      --(YT01)-E     
  
      OPEN Cur_Order_TriggerPoints    
      FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_MBOLKey, @c_MBOLLineNumber, @c_Storerkey  
  
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         -- Execute SP - isp_ITF_ntrTransfer   
         EXECUTE dbo.isp_ITF_ntrPOD     
                  @c_TriggerName    = 'ntrPODUpdate'  
                , @c_SourceTable    = 'POD'    
                , @c_Storerkey      = @c_Storerkey  
                , @c_MBOLKey        = @c_MBOLKey    
                , @c_MBOLLineNumber = @c_MBOLLineNumber    
                , @b_ColumnsUpdated = @b_ColumnsUpdated      
                , @b_Success        = @b_Success   OUTPUT    
                , @n_err            = @n_err       OUTPUT    
                , @c_errmsg         = @c_errmsg    OUTPUT    
  
         FETCH NEXT FROM Cur_Order_TriggerPoints INTO @c_MBOLKey, @c_MBOLLineNumber, @c_Storerkey  
      END -- WHILE @@FETCH_STATUS <> -1    
      CLOSE Cur_Order_TriggerPoints    
      DEALLOCATE Cur_Order_TriggerPoints    
   END -- IF @n_continue = 1 OR @n_continue = 2     
   /********************************************************/    
   /* Interface Trigger Points Calling Process - (End)     */    
   /********************************************************/    
   -- (MC01) - E  
  
     /* #INCLUDE <TRPOHA2.SQL> */    
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPODUpdate'    
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