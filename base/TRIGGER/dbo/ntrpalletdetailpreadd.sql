SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Trigger: ntrPalletDetailPreAdd                                       */
/* Creation Date:                                                       */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records Inserted                                     */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  ver  Purposes                                   */
/* 2012-Nov-30  Chew KP   1.1   Auto Gen PalletLinenumber (ChewKP01)    */
/* 2018-Dec-19  TLTING01  1.2   missing NOLOCK                          */
/* 31-Mar-2020  kocy      1.3   Skip when data move from Archive (kocy01)*/
/* 12-Jan-2021  Shong     1.4   Performance Tuning, Move the logic from */
/*                              Pre-Add Trigger                         */
/* 05-May-2022  TLTING02  1.5   variable extend field length            */
/* 17-Jul-2024  PPA371    1.6   Added OrderKey and TrackingNo columns   */
/************************************************************************/
CREATE   TRIGGER [dbo].[ntrPalletDetailPreAdd]
ON  [dbo].[PALLETDETAIL]
INSTEAD OF INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success              INT -- Populated by calls to stored procedures - was the proc successful?
          ,@n_err                  INT -- Error number returned by stored procedure or this trigger
          ,@n_err2                 INT -- For Additional Error Detection
          ,@c_errmsg               NVARCHAR(250) -- Error message returned by stored procedure or this trigger
          ,@n_Continue             INT
          ,@n_StartTCnt            INT -- Holds the current transaction count@n_StorerMinShelfLife_Per
          ,@c_preprocess           NVARCHAR(250) -- preprocess
          ,@c_pstprocess           NVARCHAR(250) -- post process
          ,@n_cnt                  INT


    DECLARE @c_StorerKey    NVARCHAR(15)
           ,@c_Sku          NVARCHAR(20)
           ,@n_Qty          INT
           ,@c_PalletKey    NVARCHAR(30)
           ,@c_CaseID       NVARCHAR(20)
           ,@c_Status       NVARCHAR(10)
           ,@cPalletLine    NVARCHAR(5)   -- (ChewKP01)

   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT


   DECLARE @t_PalletDetail TABLE (
	[PalletKey] [nvarchar](30) NOT NULL,
	[PalletLineNumber] [nvarchar](5) NOT NULL,
	[CaseId] [nvarchar](20) NULL DEFAULT '',
	[StorerKey] [nvarchar](15) NOT NULL DEFAULT '',
	[Sku] [nvarchar](20) NOT NULL DEFAULT '',
	[Loc] [nvarchar](10) NOT NULL DEFAULT '',
	[Qty] [int] NOT NULL DEFAULT 0,
	[Status] [nvarchar](10) NOT NULL DEFAULT '0',
	[AddDate] [datetime] NOT NULL DEFAULT GETDATE(),
	[AddWho] [nvarchar](128) NOT NULL DEFAULT SUSER_SNAME(),
	[EditDate] [datetime] NOT NULL DEFAULT GETDATE(),
	[EditWho] [nvarchar](128) NOT NULL DEFAULT SUSER_SNAME(),
	[TrafficCop] [nvarchar](1) NULL,
	[ArchiveCop] [nvarchar](1) NULL,
	[TimeStamp] [nvarchar](18) NULL,
	[UserDefine01] [nvarchar](30) NULL,
	[UserDefine02] [nvarchar](40) NULL,  -- TLTING02
	[UserDefine03] [nvarchar](30) NULL,
	[UserDefine04] [nvarchar](30) NULL,
	[UserDefine05] [nvarchar](30) NULL ,
	[OrderKey] [nvarchar](10) NULL,
	[TrackingNo] [nvarchar](40) NULL
	)

   INSERT INTO @t_PalletDetail
   (
      PalletKey,     PalletLineNumber, CaseId,        StorerKey,
      Sku,           Loc,              Qty,           [Status],
      AddDate,       AddWho,           EditDate,      EditWho,
      TrafficCop,    ArchiveCop,       [TimeStamp],   UserDefine01,
      UserDefine02,  UserDefine03,     UserDefine04,  UserDefine05,
	   OrderKey , TrackingNo
   )
   SELECT
      PalletKey,     PalletLineNumber, CaseId,        StorerKey,
      Sku,           Loc,              Qty,           [Status],
      AddDate,       AddWho,           EditDate,      EditWho,
      TrafficCop,    ArchiveCop,       [TimeStamp],   UserDefine01,
      UserDefine02,  UserDefine03,     UserDefine04,  UserDefine05,
	    OrderKey , TrackingNo
   FROM INSERTED

   IF EXISTS( SELECT 1 FROM @t_PalletDetail WHERE ArchiveCop = '9')
      SELECT @n_Continue = 4


    IF @n_Continue=1 OR @n_Continue=2
    BEGIN
        IF EXISTS ( SELECT 1 FROM dbo.PALLET AS P WITH (NOLOCK)
                    JOIN  @t_PalletDetail PD ON P.PalletKey = PD.PalletKey
                    WHERE P.Status = '9' )
        BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 67600
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': PALLET.Status = ''SHIPPED''. UPDATE rejected. (ntrPalletDetailPreAdd)'
        END
    END

    IF @n_Continue=1 OR @n_Continue=2
    BEGIN
        IF EXISTS (SELECT 1
                   FROM @t_PalletDetail AS PD
                   WHERE PD.StorerKey IS NULL OR PD.StorerKey = ''
                      OR PD.Sku IS NULL OR PD.SKU = '' )
        BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 67604
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': PALLETDETAIL.StorerKey or PALLETDETAIL.Sku can not be blank. (ntrPalletDetailPreAdd)'
        END
    END

    IF @n_Continue=1 OR @n_Continue=2
    BEGIN
        IF EXISTS ( SELECT 1 FROM @t_PalletDetail AS PD
                    WHERE NOT EXISTS (
                          SELECT 1
                          FROM  dbo.SKU S WITH (NOLOCK)
                          WHERE S.StorerKey = PD.StorerKey
                            AND S.Sku = PD.Sku
                      )
           )
        BEGIN
            SELECT @n_Continue = 3
            SELECT @n_err = 67605
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Bad PALLETDETAIL.StorerKey or PALLETDETAIL.Sku. (ntrPalletDetailPreAdd)'
        END
    END

 IF @n_Continue=1 OR @n_Continue=2
 BEGIN
     DECLARE CUR_CASEMANIFEST_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
     SELECT CM.StorerKey
          , CM.Sku
          , CM.Qty
          , PD.PalletKey
          , CM.CaseId
          , PD.[Status]
     FROM [dbo].[CASEMANIFEST] AS CM WITH (NOLOCK)
     JOIN @t_PalletDetail AS PD ON CM.CaseId = PD.CaseId
     WHERE PD.CaseID IS NOT NULL
     AND PD.CaseID > ''

     OPEN CUR_CASEMANIFEST_UPDATE

     FETCH FROM CUR_CASEMANIFEST_UPDATE INTO @c_StorerKey, @c_Sku, @n_Qty, @c_PalletKey, @c_CaseId, @c_Status

     WHILE @@FETCH_STATUS = 0
     BEGIN
        IF @n_Qty = 0
           SET @n_Qty = 1

        UPDATE @t_PalletDetail
        SET    TrafficCop = NULL
              ,StorerKey = @c_StorerKey
              ,Sku = @c_Sku
              ,Qty = @n_Qty
              ,EditDate = GETDATE()
              ,EditWho = SUSER_SNAME()
        WHERE PalletKey = @c_PalletKey
          AND CaseId = @c_CaseId

        SELECT @n_err = @@ERROR
              ,@n_cnt = @@ROWCOUNT

        IF @n_err<>0
        BEGIN
            SELECT @n_Continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250) ,@n_err)
                  ,@n_err = 67603 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5) ,@n_err)+
                   ': Update Failed On Table PALLETDETAIL. (ntrPalletDetailPreAdd)'+' ( '+' SQLSvr MESSAGE='+ISNULL(TRIM(@c_errmsg),'')
                  +' ) '
        END

        FETCH FROM CUR_CASEMANIFEST_UPDATE INTO @c_StorerKey, @c_Sku, @n_Qty, @c_PalletKey, @c_CaseId, @c_Status
     END

     CLOSE CUR_CASEMANIFEST_UPDATE
     DEALLOCATE CUR_CASEMANIFEST_UPDATE
 END


   IF @n_Continue=1 or @n_Continue=2
   BEGIN
      -- (ChewKP01) - Start
      IF EXISTS (SELECT 1 FROM @t_PalletDetail AS tPD WHERE tPD.PalletLineNumber = '0')
      BEGIN
         WHILE 1=1
         BEGIN
            SET @c_PalletKey = ''

            SELECT TOP 1 @c_PalletKey = PalletKey
            FROM @t_PalletDetail AS tPD
            WHERE tPD.PalletLineNumber = '0'
            ORDER BY PalletKey

            IF @c_PalletKey <> ''
            BEGIN
               SELECT @cPalletLine = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( PD.PalletLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
               FROM dbo.PalletDetail AS PD WITH (NOLOCK)
               WHERE PD.PalletKey = @c_PalletKey

               UPDATE @t_PalletDetail
                  SET PalletLineNumber = @cPalletLine
               WHERE PalletKey = @c_PalletKey
               AND PalletLineNumber = '0'

            END
            ELSE
               BREAK

         END -- While 1=1

      END
      -- (ChewKP01) - End
    END

   IF @n_Continue=1 or @n_Continue=2 OR @n_Continue = 4
   BEGIN
      INSERT INTO dbo.PALLETDETAIL
      (
         PalletKey,     PalletLineNumber, CaseId,        StorerKey,
         Sku,           Loc,              Qty,           [Status],
         AddDate,       AddWho,           EditDate,      EditWho,
         TrafficCop,    ArchiveCop,       [TimeStamp],   UserDefine01,
         UserDefine02,  UserDefine03,     UserDefine04,  UserDefine05,
		     OrderKey , TrackingNo
      )
         SELECT
         PalletKey,     PalletLineNumber, CaseId,        StorerKey,
         Sku,           Loc,              Qty,           [Status],
         AddDate,       AddWho,           EditDate,      EditWho,
         TrafficCop,    ArchiveCop,       [TimeStamp],   UserDefine01,
         UserDefine02,  UserDefine03,     UserDefine04,  UserDefine05,
		   OrderKey , TrackingNo
      FROM @t_PalletDetail
   END

 IF @n_Continue=3 -- Error Occured - Process And Return
 BEGIN
     IF @@TRANCOUNT=1
        AND @@TRANCOUNT>=@n_StartTCnt
     BEGIN
         ROLLBACK TRAN
     END
     ELSE
     BEGIN
         WHILE @@TRANCOUNT>@n_StartTCnt
         BEGIN
             COMMIT TRAN
         END
     END
     EXECUTE dbo.nsp_logerror @n_err= @n_err,
             @c_errmsg= @c_errmsg, @c_module='ntrPalletDetailPreAdd'

     RAISERROR (@c_errmsg ,16 ,1) WITH SETERROR
     RETURN
 END
 ELSE
 BEGIN
     WHILE @@TRANCOUNT>@n_StartTCnt
     BEGIN
         COMMIT TRAN
     END
     RETURN
 END

END -- Trigger

GO