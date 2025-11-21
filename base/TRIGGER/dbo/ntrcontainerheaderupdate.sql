SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Trigger:  ntrContainerHeaderUpdate                                    */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:  Trigger point upon any Update on the Container              */
/*                                                                       */
/* Return Status:  None                                                  */
/*                                                                       */
/* Usage:                                                                */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: When records updated                                       */
/*                                                                       */
/* PVCS Version: 1.5                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver.  Purposes                                 */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()      */
/* 15-Mar-2010  MCTang    1.2   SOS 164845 - Add StorerConfig.ConfigKey  */
/*                              "CONTNRLOG" (MC01)                       */
/*                              SOS Extend Palletkey from NVARCHAR(10)   */
/*                              to NVARCHAR(30) (MC02)                   */
/*                              Comment off unnecessary code (MC03)      */
/* 29-Oct-2010  MCTang    1.3   SOS 193841 - Add StorerConfig.ConfigKey  */
/*                              "CONTNR2LOG" (MC04)                      */
/* 28-Oct-2013  TLTING    1.4   Review Editdate column update            */
/* 13-Aug-2014  Leong     1.5   Revise error message. (Leong01)          */
/* 22-Dec-2018  TLTING01  1.6   missing nolock                           */
/* 26-Feb-2019  MCTang    1.7   Enhance Generic Trigger Interface (MC05) */
/*************************************************************************/

CREATE TRIGGER [dbo].[ntrContainerHeaderUpdate]
ON  [dbo].[CONTAINER]
FOR UPDATE
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

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE   @b_Success             int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err                 int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2                int       -- For Additional Error Detection
   ,         @c_errmsg              NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue            int
   ,         @n_starttcnt           int       -- Holds the current transaction count
   ,         @c_preprocess          NVARCHAR(250) -- preprocess
   ,         @c_pstprocess          NVARCHAR(250) -- post process
   ,         @n_cnt                 int
   ,         @c_StatusUpdated       CHAR(1)        --(MC05) 
   ,         @c_Proceed             CHAR(1)        --(MC05)
   ,         @c_COLUMN_NAME         VARCHAR(50)    --(MC05) 
   ,         @c_ColumnsUpdated      VARCHAR(1000)  --(MC05)
   ,         @c_ContainerKey        NVARCHAR(20)   --(MC05)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

   SET @c_StatusUpdated    = 'N'                   --(MC05)               
   SET @c_Proceed          = 'N'                   --(MC05)
   SET @c_COLUMN_NAME      = ''                    --(MC05)
   SET @c_ColumnsUpdated   = ''                    --(MC05)
   SET @c_ContainerKey     = ''

   DECLARE @b_ColumnsUpdated VARBINARY(1000)       --(MC05)
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       --(MC05)

   /* #INCLUDE <TRCONHU1.SQL> */
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Reject UPDATE when CONTAINER.Status already ''SHIPPED'''
      END
      IF EXISTS(SELECT * FROM DELETED WHERE Status = '9')
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err=68000
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+': UPDATE rejected. CONTAINER.Status is already ''SHIPPED''. (ntrContainerHeaderUpdate)'
      END
   END

   IF @n_continue = 1 or @n_continue=2
   BEGIN

      IF @b_debug = 1
      BEGIN
         PRINT 'Update PALLET.Status to ''SHIPPED'''
      END

      UPDATE PALLET WITH (ROWLOCK)
      SET Status = '9',
         EditDate = GETDATE(),   --tlting
         EditWho = SUSER_SNAME()
      FROM PALLET, CONTAINERDETAIL (NOLOCK), INSERTED   --tlting01
      WHERE CONTAINERDETAIL.ContainerKey = INSERTED.ContainerKey
      AND PALLET.PalletKey = CONTAINERDETAIL.PalletKey
      AND NOT PALLET.Status = '9'
      AND INSERTED.Status = '9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+': Update Failed On Table PALLET. (ntrContainerHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   -- (MC03) - S
   /*
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Update ITRANHDR'
      END

      DECLARE  @ContainerKey  NVARCHAR(20),
               @ContainerType NVARCHAR(10),
               @PalletKey     NVARCHAR(30),   -- MC02
               @ItrnKey       NVARCHAR(10),
               @StorerKey     NVARCHAR(15),
               @c_InsertedStatus    NVARCHAR(10),
               @c_MbolKey           NVARCHAR(10),
               @c_authority_contnr  NVARCHAR(1)

      SELECT @ContainerKey = ''

      WHILE (@n_continue=1 or @n_continue=2) -- by ContainerKey
      BEGIN

         SET @c_InsertedStatus = '' -- MC01
         SET @c_MbolKey = ''

         SET ROWCOUNT 1
         SELECT @ContainerKey = ContainerKey,
                @ContainerType = ContainerType,
                @c_InsertedStatus = Status, -- MC01
                @c_MbolKey = MbolKey --MC01
         FROM INSERTED
         WHERE ContainerKey > @ContainerKey
         AND Status = '9'
         ORDER BY ContainerKey

         IF @@ROWCOUNT = 0  BREAK

         SET ROWCOUNT 0

         IF @b_debug = 1
         BEGIN
            PRINT 'ContainerKey: ' + @ContainerKey
         END

         SELECT @storerkey = NVARCHAR(14)

         WHILE (@n_continue=1 or @n_continue=2) -- by ContainerKey, StorerKey
         BEGIN

            SET ROWCOUNT 1

            SELECT @storerkey = CM.StorerKey
            FROM CONTAINERDETAIL CD WITH (NOLOCK), PALLETDETAIL PD WITH (NOLOCK), CASEMANIFEST CM WITH (NOLOCK)
            WHERE CD.ContainerKey = @ContainerKey
            and PD.PalletKey = CD.PalletKey
            and PD.CaseId = CM.CaseId
            and CM.StorerKey > @StorerKey
            ORDER BY CM.StorerKey

            IF @@ROWCOUNT = 0 BREAK

            SET ROWCOUNT 0
            IF @b_debug = 1
            BEGIN
               PRINT 'StorerKey: ' + @StorerKey
            END

            EXECUTE nspBillContainer
                       @c_sourcetype    = 'CNT'
                     , @c_sourcekey     = @ContainerKey
                     , @c_containertype = @ContainerType
                     , @n_containerqty  = 1
                     , @c_storerkey     = @StorerKey
                     , @b_Success       = @b_Success   OUTPUT
                     , @n_err           = @n_err       OUTPUT
                     , @c_errmsg        = @c_errmsg    OUTPUT

            IF NOT @b_Success = 1  SELECT @n_continue = 3
         END -- end loop by ContainerKey, StorerKey

         SET ROWCOUNT 0

         SELECT @PalletKey = ''

         WHILE (@n_continue=1 or @n_continue=2) -- by ContainerKey, PalletKey
         BEGIN

            SET ROWCOUNT 1

            SELECT @PalletKey = PalletKey
            FROM CONTAINERDETAIL WITH (NOLOCK)
            WHERE ContainerKey = @ContainerKey
            AND PalletKey > @PalletKey
            ORDER BY ContainerKey, PalletKey

            IF @@ROWCOUNT = 0  BREAK

            SET ROWCOUNT 0

            IF @b_debug = 1
            BEGIN
               PRINT 'PalletKey: ' + @PalletKey
            END

            SELECT @ItrnKey = ''

            WHILE (@n_continue=1 or @n_continue=2)   -- by ContainerKey, PalletKey, ITRNKey
            BEGIN
               SET ROWCOUNT 1

               SELECT @ItrnKey = ItrnKey
               FROM ITRNHDR WITH (NOLOCK)
               WHERE HeaderKey = @PalletKey
               AND ItrnKey > @ItrnKey
               AND HeaderType = 'PA'
               ORDER BY HeaderKey, ItrnKey

               IF @@ROWCOUNT = 0
               BEGIN
                  BREAK
               END

               SET ROWCOUNT 0

               IF @b_debug = 1
               BEGIN
                  PRINT 'ITRNKey: ' + @ITRNKey
               END

               INSERT ITRNHDR (HeaderType, ItrnKey, HeaderKey)
               VALUES ('CO',   @ItrnKey,  @PalletKey)

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+': Update Failed On Table ITRNHDR. (ntrContainerHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END
            END -- end LOOP by ContainerKey, PalletKey, ITRNKey

            SET ROWCOUNT 0
         END -- end LOOP by ContainerKey, PalletKey

         SET ROWCOUNT 0

      END -- end LOOP by ContainerKey

      SET ROWCOUNT 0
   END
   */
   -- (MC03) - E

   -- SOS164845 MC01 Start
   IF @n_continue = 1 or @n_continue=2
   BEGIN
      DECLARE  @ContainerKey        NVARCHAR(20),
               @c_StorerKey         NVARCHAR(15),
               @c_InsertedStatus    NVARCHAR(10),
               @c_MbolKey           NVARCHAR(10),
               @c_authority_contnr  NVARCHAR(1)

      SET @ContainerKey = ''

      WHILE (@n_continue=1 or @n_continue=2) -- by ContainerKey
      BEGIN

         SET @c_InsertedStatus = ''
         SET @c_MbolKey = ''
         SET @c_storerkey = ''

         SELECT TOP 1 @ContainerKey = ContainerKey,
                @c_InsertedStatus = Status,
                @c_MbolKey = MbolKey
         FROM INSERTED
         WHERE ContainerKey > @ContainerKey
         AND Status = '9'
         ORDER BY ContainerKey

         IF @@ROWCOUNT = 0  BREAK


         IF @b_debug = 1
         BEGIN
            PRINT 'ContainerKey: ' + @ContainerKey
         END

         IF @c_InsertedStatus = '9' AND ISNULL(@c_MbolKey, '') <> ''
         BEGIN

            DECLARE C_MBOL_OrderKey CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Distinct ORDERS.StorerKey
            FROM MBOLDetail MBOLDetail WITH (NOLOCK)
            JOIN ORDERS ORDERS WITH (NOLOCK)
            ON (MBOLDetail.OrderKey = ORDERS.OrderKey )
            WHERE MBOLDetail.MBOLKEY = ISNULL(@c_MbolKey, '')

            OPEN C_MBOL_OrderKey
            FETCH NEXT FROM C_MBOL_OrderKey INTO @c_StorerKey

            WHILE @@FETCH_STATUS <> -1 and @n_continue = 1
            BEGIN

               EXECUTE dbo.nspGetRight
                        NULL,              -- Facility
                        @c_StorerKey,      -- StorerKey
                        '',
                        'CONTNRLOG',       -- ConfigKey
                        @b_success          OUTPUT,
                        @c_authority_contnr OUTPUT,
                        @n_err              OUTPUT,
                        @c_errmsg           OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (CONTNRLOG) Failed (ntrContainerHeaderUpdate) ( ' -- (Leong01)
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               END

               IF @c_authority_contnr = '1'
               BEGIN
                  EXEC dbo.ispGenTransmitLog3 'CONTNRLOG', @ContainerKey, '', @c_StorerKey, ''
                                    , @b_success OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
                  ELSE
                  BEGIN
                     EXEC dbo.ispGenTransmitLog3 'CONTNR2LOG', @ContainerKey, '', @c_StorerKey, ''
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END
               END  -- IF @c_authority_contnr = '1'

               FETCH NEXT FROM C_MBOL_OrderKey INTO @c_StorerKey
            END -- WHILE @@FETCH_STATUS <> -1 and @n_continue = 1
            CLOSE C_MBOL_OrderKey
            DEALLOCATE C_MBOL_OrderKey
         END --IF @c_InsertedStatus.Status = '9' AND ISNULL(@c_MbolKey, '') <> ''

      END -- end LOOP by ContainerKey

      SET ROWCOUNT 0
   END
   -- SOS164845 MC01 End

   --(MC05) - S
   DECLARE Cur_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT DISTINCT INS.ContainerKey, OH.StorerKey
   FROM   INSERTED INS 
   JOIN   MBOLDetail MD WITH (NOLOCK) ON INS.MbolKey = MD.MbolKey
   JOIN   Orders OH WITH (NOLOCK)     ON MD.OrderKey = OH.OrderKey  

   OPEN Cur_TriggerPoints  
   FETCH NEXT FROM Cur_TriggerPoints INTO @c_ContainerKey, @c_Storerkey

   WHILE @@FETCH_STATUS <> -1  
   BEGIN

      SET @c_Proceed = 'N'

      IF EXISTS ( SELECT 1 
   	            FROM  ITFTriggerConfig ITC WITH (NOLOCK)       
   	            WHERE ITC.StorerKey   = @c_Storerkey
   	            AND   ITC.SourceTable = 'CONTAINER'  
                  AND   ITC.sValue      = '1' )
      BEGIN
         SET @c_Proceed = 'Y'           
      END

      -- For OTMLOG StorerKey = 'ALL'
   	IF EXISTS ( SELECT 1 
   	            FROM  StorerConfig STC WITH (NOLOCK)        
   	            WHERE STC.StorerKey = @c_Storerkey 
   	            AND   STC.SValue    = '1' 
   	            AND   EXISTS(SELECT 1 
                               FROM  ITFTriggerConfig ITC WITH (NOLOCK)
   	                         WHERE ITC.StorerKey   = 'ALL' 
   	                         AND   ITC.SourceTable = 'CONTAINER'  
                               AND   ITC.sValue      = '1' 
                               AND   ITC.ConfigKey = STC.ConfigKey ) )
      BEGIN                  
         SET @c_Proceed = 'Y'                          	
      END       

      IF @c_Proceed = 'Y'
      BEGIN

         SET @c_ColumnsUpdated = ''    

         DECLARE Cur_ColUpdated CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT COLUMN_NAME FROM dbo.fnc_GetUpdatedColumns('CONTAINER', @b_ColumnsUpdated) 
         OPEN Cur_ColUpdated  
         FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME
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

            FETCH NEXT FROM Cur_ColUpdated INTO @c_COLUMN_NAME
         END -- WHILE @@FETCH_STATUS <> -1  
         CLOSE Cur_ColUpdated  
         DEALLOCATE Cur_ColUpdated  

         EXECUTE dbo.isp_ITF_ntrContainer
                    @c_TriggerName    = 'ntrContainerHeaderUpdate'
                  , @c_SourceTable    = 'CONTAINER'  
                  , @c_Storerkey      = @c_Storerkey
                  , @c_ContainerKey   = @c_ContainerKey   
                  , @c_ColumnsUpdated = @c_ColumnsUpdated 
                  , @b_Success        = @b_Success   OUTPUT  
                  , @n_err            = @n_err       OUTPUT  
                  , @c_errmsg         = @c_errmsg    OUTPUT 
      END

      FETCH NEXT FROM Cur_TriggerPoints INTO @c_ContainerKey, @c_Storerkey
   END -- WHILE @@FETCH_STATUS <> -1  
   CLOSE Cur_TriggerPoints  
   DEALLOCATE Cur_TriggerPoints 
   --(MC05) - E

   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Update EditDate and EditWho'
      END

      UPDATE CONTAINER WITH (ROWLOCK)
      SET   EditDate = GETDATE(),
            EditWho = SUSER_SNAME(),
            Trafficcop = NULL
      FROM CONTAINER
      JOIN INSERTED ON (CONTAINER.ContainerKey = INSERTED.ContainerKey)

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
         BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68004   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),ISNULL(@n_err,0))+': Update Failed On Table CONTAINER. (ntrContainerHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   /* #INCLUDE <TRCONHU2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrContainerHeaderUpdate'
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