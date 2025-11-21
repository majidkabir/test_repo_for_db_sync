SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ntrCartonTrackUpdate                                        */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  CartonTrack Update Transaction                             */  
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
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 28-Oct-2013  TLTING   1.1  Review Editdate column update             */
/* 25-May-2016  TLTING   1.2  Add ArchiveCop check skip task            */
/* 14-Oct-2016  SHONG    1.3  Not Allow to Update LabelNo if already    */
/*                            assigned to other orderkey                */
/* 25-Jul-2017  KHChan   1.4  Add WS trigger point for ConfigKey =      */
/*                            WSCTDELIVERED #WMS-2032 (KH01)            */  
/* 28-Sep-2017  KHChan   1.5  Add RowRef into Transmitlog2 (KH02)       */  
/* 02-Jan-2018  KHChan   1.6  Add Trigger point #WMS-3237 (KH03)        */
/* 04-Jan-2018  KHChan   1.6  Added Generic Trigger for Interface.      */
/*                            Remark KH03 (KH04)                        */
/************************************************************************/    
CREATE TRIGGER [dbo].[ntrCartonTrackUpdate]
ON [dbo].[CartonTrack]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT=0
   BEGIN
       RETURN
   END
   
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @b_Success          INT -- Populated by calls to stored procedures - was the proc successful?  
           , @n_err            INT -- Error number returned by stored procedure or this trigger  
           , @n_err2           INT -- For Additional Error Detection  
           , @c_errmsg         NVARCHAR(250) -- Error message returned by stored procedure or this trigger  
           , @n_continue INT, @n_starttcnt INT -- Holds the current transaction count  
           , @c_preprocess     NVARCHAR(250) -- preprocess  
           , @c_pstprocess     NVARCHAR(250) -- post process  
           , @n_cnt            INT    
           , @c_StorerKey      NVARCHAR(15) --(KH01)
           , @c_OrderKey       NVARCHAR(15) --(KH01)
           , @c_authority_WSCTDELIVERED NVARCHAR(1) --(KH01)
           , @n_RowRef         INT --(KH02)
           , @c_authority_WSCTUDF01 NVARCHAR(1) --(KH03)
           , @c_UDF01 NVARCHAR(30) --(KH03)
           , @c_UDF03 NVARCHAR(30) --(KH03)
           , @c_ColumnsUpdated VARCHAR(1000) --(KH04)
           , @c_COLUMN_NAME VARCHAR(50) --(KH04)

   SET @c_StorerKey = '' --(KH01)
   SET @c_OrderKey = '' --(KH01)
   SET @c_authority_WSCTDELIVERED = '' --(KH01)
   SET @n_RowRef = 0 --(KH02)
   SET @c_authority_WSCTUDF01 = '' --(KH03)
   SET @c_UDF01 = '' --(KH03)
   SET @c_UDF03 = '' --(KH03)
   SET @c_ColumnsUpdated = '' --(KH04)
   SET @c_COLUMN_NAME = '' --(KH04)

   DECLARE @b_ColumnsUpdated VARBINARY(1000) --(KH04)
   SET @b_ColumnsUpdated = COLUMNS_UPDATED() --(KH04)

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT  
   
   IF UPDATE (ArchiveCop)
   BEGIN
       SELECT @n_Continue = 4
       GOTO QUIT
   END
   
   IF (@n_continue=1 OR @n_continue=2) AND UPDATE (LabelNo)   
   BEGIN
   	IF EXISTS(SELECT 1 FROM DELETED 
   	          JOIN INSERTED ON DELETED.RowRef = INSERTED.RowRef   
   	          WHERE DELETED.CarrierRef2 = 'GET' 
   	            AND DELETED.LabelNo <> ''
   	            AND INSERTED.CarrierRef2 <> 'PEND')
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(CHAR(250), @n_err), @n_err = 69701 
          SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5), @n_err)+
                 ': Update Failed On Table CartonTrack. Tracking No already assigned (ntrCartonTrackUpdate)' 
      END   	 
   END 
   	   
   IF (@n_continue=1 OR @n_continue=2) AND NOT UPDATE (EditDate)   
   BEGIN
      UPDATE CartonTrack  WITH (ROWLOCK)
      SET    EditDate = GETDATE(), EditWho = SUSER_SNAME()
      FROM   CartonTrack, INSERTED(NOLOCK)
      WHERE  CartonTrack.RowRef = INSERTED.RowRef  
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT  
      
      IF @n_err<>0
      BEGIN
          SELECT @n_continue = 3  
          SELECT @c_errmsg = CONVERT(CHAR(250), @n_err), @n_err = 69702  
          SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5), @n_err)+
                 ': Update Failed On Table CartonTrack. (ntrCartonTrackUpdate)'+' ( '+' SQLSvr MESSAGE='+LTRIM(RTRIM(@c_errmsg)) 
                +' ) '
      END
   END 

   --(KH01) - Start
   IF (@n_continue=1 OR @n_continue=2) AND UPDATE (CarrierRef2)   
   BEGIN
   
      DECLARE C_CTUpdCarrierRef2  CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR     
         SELECT INSERTED.LabelNo, ORDERS.StorerKey  
               ,INSERTED.RowRef --(KH02)
         FROM   INSERTED   
         JOIN   ORDERS WITH (NOLOCK) ON (INSERTED.LabelNo = ORDERS.OrderKey)   
         WHERE  INSERTED.CarrierRef2 = 'DELIVERED'
         ORDER BY INSERTED.LabelNo  
                  ,INSERTED.RowRef --(KH02)
        
      OPEN C_CTUpdCarrierRef2  
      FETCH NEXT FROM C_CTUpdCarrierRef2 INTO @c_OrderKey, @c_StorerKey, @n_RowRef --(KH02)
                                                  
      WHILE 1=1
      BEGIN  
         --FETCH NEXT FROM C_CTUpdCarrierRef2 INTO @c_OrderKey, @c_StorerKey --(KH02)

     
         IF @@FETCH_STATUS = -1  
            BREAK  

         SET @c_authority_WSCTDELIVERED = ''
         SET @b_success = 0

         EXECUTE nspGetRight '',   
                  @c_StorerKey,              -- Storer  
                  '',                        
                  'WSCTDELIVERED',           -- ConfigKey  
                  @b_success                 output,   
                  @c_authority_WSCTDELIVERED output,   
                  @n_err                     output,   
                  @c_errmsg                  output  
  
         IF @b_success <> 1   
         BEGIN  
            SELECT @n_continue = 3, @c_errmsg = 'ntrCartonTrackUpdate - Unable to verify ConfigKey WSCTDELIVERED. '  
         END  


         IF (ISNULL(RTRIM(@c_authority_WSCTDELIVERED),'') = '1') 
         BEGIN
            --EXEC ispGenTransmitLog2 'WSCTDELIVERED', @c_OrderKey, '', @c_StorerKey, '' --(KH02)
            EXEC ispGenTransmitLog2 'WSCTDELIVERED', @c_OrderKey, @n_RowRef, @c_StorerKey, '' --(KH02)
            , @b_success OUTPUT  
            , @n_err OUTPUT  
            , @c_errmsg OUTPUT  
  
            IF @b_success <> 1  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810     
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                 + ': Unable to obtain Transmitlogkey2 (ntrCartonTrackUpdate)'   
                                 + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END  
         END

         FETCH NEXT FROM C_CTUpdCarrierRef2 INTO @c_OrderKey, @c_StorerKey --(KH02)
                                                , @n_RowRef --(KH02)
      END  
      CLOSE C_CTUpdCarrierRef2  
      DEALLOCATE C_CTUpdCarrierRef2  

   END
   --(KH01) - End

   /* --(KH04) - Remark
   --(KH03) - Start
   IF (@n_continue=1 OR @n_continue=2) AND UPDATE (UDF01)   
   BEGIN
   
      DECLARE C_CTUpdUDF01 CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR     
         SELECT INSERTED.LabelNo, ORDERS.StorerKey  
               ,INSERTED.RowRef, INSERTED.UDF01, INSERTED.UDF03
         FROM   INSERTED   
         JOIN   ORDERS WITH (NOLOCK) ON (INSERTED.LabelNo = ORDERS.OrderKey)   
         WHERE  INSERTED.UDF03 = 'S'
         UNION
         SELECT RECEIPT.ReceiptKey, RECEIPT.StorerKey  
               ,INSERTED.RowRef, INSERTED.UDF01, INSERTED.UDF03
         FROM   INSERTED   
         JOIN   RECEIPT WITH (NOLOCK) ON (INSERTED.LabelNo = RECEIPT.ExternReceiptKey)
         WHERE  INSERTED.UDF03 = 'R'

         ORDER BY INSERTED.LabelNo  
                  ,INSERTED.RowRef
        
      OPEN C_CTUpdUDF01  
      FETCH NEXT FROM C_CTUpdUDF01 INTO @c_OrderKey, @c_StorerKey, @n_RowRef, @c_UDF01, @c_UDF03
                                                  
      WHILE 1=1
      BEGIN  

         IF @@FETCH_STATUS = -1  
            BREAK  

         SET @c_authority_WSCTUDF01 = ''
         SET @b_success = 0

         EXECUTE nspGetRight '',   
                  @c_StorerKey,              -- Storer  
                  '',                        
                  'WSCTUDF01',           -- ConfigKey  
                  @b_success                 output,   
                  @c_authority_WSCTUDF01     output,   
                  @n_err                     output,   
                  @c_errmsg                  output  
  
         IF @b_success <> 1   
         BEGIN  
            SELECT @n_continue = 3, @c_errmsg = 'ntrCartonTrackUpdate - Unable to verify ConfigKey WSCTUDF01. '  
         END  


         IF (ISNULL(RTRIM(@c_authority_WSCTUDF01),'') = '1') 
         BEGIN
            IF @c_UDF03 = 'S' --Order
            BEGIN
               IF @c_UDF01 = '01'
                  EXEC ispGenTransmitLog2 'WSCTPICKGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT  
               ELSE IF @c_UDF01 = '82'
                  EXEC ispGenTransmitLog2 'WSCTPARRGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT  
               ELSE IF @c_UDF01 = '84'
                  EXEC ispGenTransmitLog2 'WSCTFAILGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT 
               ELSE IF @c_UDF01 = '91'
                  EXEC ispGenTransmitLog2 'WSCTARRGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT 
               ELSE
                  SET @b_success = 1

               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810     
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                    + ': Unable to obtain Transmitlogkey2 (ntrCartonTrackUpdate)'   
                                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               END
            END --IF @c_UDF03 = 'S'
            ELSE IF @c_UDF03 = 'R' --Return
            BEGIN
               IF @c_UDF01 = '01'
                  EXEC ispGenTransmitLog2 'WSCTRTNPICKGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT  
               ELSE IF @c_UDF01 = '82'
                  EXEC ispGenTransmitLog2 'WSCTRTNPARRGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT  
               ELSE IF @c_UDF01 = '91'
                  EXEC ispGenTransmitLog2 'WSCTRTNARRGS', @c_OrderKey, @n_RowRef, @c_StorerKey, '' 
                  , @b_success OUTPUT  
                  , @n_err OUTPUT  
                  , @c_errmsg OUTPUT 
               ELSE
                  SET @b_success = 1

               IF @b_success <> 1  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810     
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                    + ': Unable to obtain Transmitlogkey2 (ntrCartonTrackUpdate)'   
                                    + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
               END
            END --ELSE IF @c_UDF03 = 'R'
         END --IF (ISNULL(RTRIM(@c_authority_WSCTUDF01),'') = '1') 

         FETCH NEXT FROM C_CTUpdUDF01 INTO @c_OrderKey, @c_StorerKey, @n_RowRef, @c_UDF01, @c_UDF03
      END  
      CLOSE C_CTUpdUDF01  
      DEALLOCATE C_CTUpdUDF01  

   END --IF (@n_continue=1 OR @n_continue=2) AND UPDATE (UDF01) 
   --(KH03) - End
   */

   --(KH04) - S
   /********************************************************/
   /* Interface Trigger Points Calling Process - (Start)   */
   /********************************************************/
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
	   DECLARE @t_ColumnUpdated TABLE (COLUMN_NAME NVARCHAR(50))
	
	   SET @c_ColumnsUpdated = ''
	
      DECLARE Cur_CT_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      -- Extract values for required variables
       SELECT DISTINCT INS.RowRef, ORDERS.OrderKey, ORDERS.StorerKey
       FROM INSERTED INS
       JOIN ORDERS WITH (NOLOCK) ON (INS.LabelNo = ORDERS.OrderKey)   
       JOIN ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = ORDERS.StorerKey
       WHERE ITC.SourceTable = 'CARTONTRACK'
       AND ITC.sValue = '1'

       UNION

       SELECT DISTINCT INS.RowRef, RECEIPT.ReceiptKey, RECEIPT.StorerKey 
       FROM INSERTED INS
       JOIN RECEIPT WITH (NOLOCK) ON (INS.LabelNo = RECEIPT.ExternReceiptKey)   
       JOIN ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = RECEIPT.StorerKey
       WHERE ITC.SourceTable = 'CARTONTRACK'
       AND ITC.sValue = '1'

      OPEN Cur_CT_TriggerPoints
      FETCH NEXT FROM Cur_CT_TriggerPoints INTO @n_RowRef, @c_OrderKey, @c_StorerKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         IF ISNULL(RTRIM(@c_ColumnsUpdated),'') = ''
         BEGIN
      	   INSERT INTO @t_ColumnUpdated
      	   SELECT COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('CARTONTRACK', @b_ColumnsUpdated)
      	
            DECLARE Cur_CT_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT COLUMN_NAME FROM @t_ColumnUpdated
            OPEN Cur_CT_ColUpdated
            FETCH NEXT FROM Cur_CT_ColUpdated INTO @c_COLUMN_NAME
            WHILE @@FETCH_STATUS <> -1
            BEGIN
            
               IF @c_ColumnsUpdated = ''
               BEGIN
                  SET @c_ColumnsUpdated = @c_COLUMN_NAME
               END
               ELSE
               BEGIN
                  SET @c_ColumnsUpdated = @c_ColumnsUpdated + ',' + @c_COLUMN_NAME
               END

               FETCH NEXT FROM Cur_CT_ColUpdated INTO @c_COLUMN_NAME
            END -- WHILE @@FETCH_STATUS <> -1
            CLOSE Cur_CT_ColUpdated
            DEALLOCATE Cur_CT_ColUpdated
         END --IF ISNULL(RTRIM(@c_ColumnsUpdated),'') = ''

         EXECUTE dbo.isp_ITF_ntrCartonTrack
                  @c_TriggerName = 'ntrCartonTrackUpdate'
                , @c_SourceTable = 'CARTONTRACK'
                , @n_RowRef = @n_RowRef
                , @c_OrderKey = @c_OrderKey
                , @c_StorerKey = @c_StorerKey
                , @c_ColumnsUpdated = @c_ColumnsUpdated
                , @b_Success = @b_Success OUTPUT
                , @n_err = @n_err OUTPUT
                , @c_errmsg = @c_errmsg OUTPUT

         FETCH NEXT FROM Cur_CT_TriggerPoints INTO @n_RowRef, @c_OrderKey, @c_StorerKey
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_CT_TriggerPoints
      DEALLOCATE Cur_CT_TriggerPoints
   END -- IF @n_continue = 1 OR @n_continue = 2
   /********************************************************/
   /* Interface Trigger Points Calling Process - (End)     */
   /********************************************************/
   --(KH04) - E

   QUIT: 
   
   IF @n_continue=3 -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT=1
         AND @@TRANCOUNT>=@n_starttcnt
      BEGIN
          ROLLBACK TRAN
      END
      ELSE
      BEGIN
          WHILE @@TRANCOUNT>@n_starttcnt
          BEGIN
              COMMIT TRAN
          END
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrCartonTrackUpdate' 
      RAISERROR (@c_errmsg, 16, 1) 
      WITH SETERROR -- SQL2012  
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT>@n_starttcnt
      BEGIN
          COMMIT TRAN
      END 
      RETURN
   END
END  

GO