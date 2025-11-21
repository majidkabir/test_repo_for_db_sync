SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPackDetailUpdate                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
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
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2005-JAN-07  Shong           Bug fixing                              */
/* 2005-Jun-15  June             Script merging : SOS18664 done by Wanyt*/
/* 2007-July-26 Wanyt           SOS#80943 - Not to Delete Qty = 0 for   */
/*                              Pre-Cartonize                           */
/* 2008-Oct-22  James     1.1   Change @@TRANCOUNT >= @n_starttcnt      */
/* 2008-Dec-17  NJOW      1.2   SOS124169 remove label# from pickdetail */
/*                              when the line deleted at packdetail     */
/* 2011-Apr-08  AQSKC     1.3   SOS210154 - Auto Shortpick When ExpQty  */
/*                              Reduced (Kc01)                          */
/* 2011-Nov-14  Ung       1.4   Add RDT compatible message              */
/* 2012-Apr-05  KHLim01   1.6   move up EditDate & check PK value change*/
/* 2013-Jul-13  TLTING    1.7   ArchiveCop for keep trigger script      */
/* 28-Oct-2013  TLTING    1.8   Review Editdate column update           */
/* 30-Nov-2015  NJOW01    1.9   356837-fix edit packdetail.qty update to*/
/*                              packinfo.qty                            */
/* 14-JUN-2017  Wan01     2.0   WMS-1816 - CN_DYSON_Exceed_ECOM PACKING */
/* 19-Sep-2017  TLTING01  2.1   perfromance tune - catonno 0, no dellog */
/* 19-Jul-2019  WLChooi   2.2   WMS-9661 & WMS-9663 - Add CartonGID when*/ 
/*                              add new carton - Based on storerconfig  */
/*                              Use nspGetRight to get Storerconfig to  */
/*                              filter by Facility for Pickslipno start */
/*                              with P only (Non-ECOM)                  */
/*                              For ECOM, will be done in update trigger*/
/*                              (WL01)                                  */
/* 01-Sep-2020  NJOW02    2.3   WMS-15009 - call custom stored proc     */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPackDetailUpdate] ON [dbo].[PackDetail]
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

     DECLARE @b_Success             int,       -- Populated by calls to stored procedures - was the proc successful?
             @n_err                 int,       -- Error number returned by stored procedure or this trigger
             @c_errmsg              NVARCHAR(250), -- Error message returned by stored procedure or this trigger
             @n_continue            int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
             @n_starttcnt           int,       -- Holds the current transaction count
             @n_cnt                 int        -- Holds the number of rows affected by the Update statement that fired this trigger.
            ,@c_authority           NVARCHAR(1)     -- KHLim01
            ,@c_Storerkey           NVARCHAR(10) --WL01
            ,@c_Facility            NVARCHAR(10) --WL01 
            ,@c_CartonGID           NVARCHAR(50) --WL01
            ,@c_DefaultPackInfo     NVARCHAR(10) = ''  --WL01
            ,@c_PackCartonGID       NVARCHAR(10) = ''  --WL01

     SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @b_success=0, @n_err=0, @c_errmsg=""

     DECLARE @c_Pickdetailkey NVARCHAR(10)    --(Kc01)
           , @n_ShortPackQty     int            --(KC01)

      DECLARE @c_TracePSNo    NVARCHAR(10) --L01
            , @c_ArchiveCop   NVARCHAR(10)

      SELECT @c_TracePSNo = PickSlipNo
           , @c_ArchiveCop = ArchiveCop
      FROM INSERTED

      IF UPDATE(ArchiveCop) AND EXISTS ( Select 1 FROM INSERTED WHERE ARCHIVECOP = '9' )
      BEGIN
         SELECT @n_continue = 4
      END

      --Get Facility and Configkey (WL01 Start)
      IF @n_continue = 1 or @n_continue = 2  
      BEGIN 
         SELECT TOP 1 @c_Storerkey = PACKHEADER.StorerKey
         FROM INSERTED
         JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo 
      
         SELECT TOP 1 @c_Facility = Facility
         FROM INSERTED
         JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo 
         JOIN ORDERS (NOLOCK) ON PACKHEADER.StorerKey = ORDERS.StorerKey AND PACKHEADER.OrderKey = ORDERS.OrderKey
         
         IF(ISNULL(@c_Facility,'') = '')
         BEGIN
            SELECT TOP 1 @c_Facility = ORDERS.Facility
            FROM INSERTED
            JOIN PACKHEADER (NOLOCK) ON INSERTED.PickSlipNo = PACKHEADER.PickSlipNo 
            JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.LOADKEY = PACKHEADER.LOADKEY
            JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY
         END
      
         EXEC nspGetRight   
            @c_Facility          -- facility  
         ,  @c_Storerkey         -- Storerkey  
         ,  NULL                 -- Sku  
         ,  'Default_PackInfo'   -- Configkey  
         ,  @b_Success           OUTPUT   
         ,  @c_DefaultPackInfo   OUTPUT   
         ,  @n_Err               OUTPUT   
         ,  @c_ErrMsg            OUTPUT 
      
         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 83049   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ntrPackdetailAdd)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         END
         
         EXEC nspGetRight   
            @c_Facility          -- facility  
         ,  @c_Storerkey         -- Storerkey  
         ,  NULL                 -- Sku  
         ,  'PackCartonGID'      -- Configkey  
         ,  @b_Success           OUTPUT   
         ,  @c_PackCartonGID     OUTPUT   
         ,  @n_Err               OUTPUT   
         ,  @c_ErrMsg            OUTPUT 
         
         IF @b_success <> 1  
         BEGIN  
            SET @n_continue = 3  
            SET @n_err = 83050   
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ntrPackdetailAdd)'   
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         END 
      END
      --(WL01 End)

      -- KHLim01 Start
      -- Added by YokeBeen on 19-Sep-2003 - Start
      IF ( @n_continue = 1 OR @n_continue = 2 ) AND NOT UPDATE(EditDate)
      BEGIN
         UPDATE PACKDETAIL with (ROWLOCK)
            SET EditDate = GetDate() ,
                EditWho = sUser_sName()
               ,ArchiveCop = NULL            -- KHLim01
           FROM PACKDETAIL
           JOIN INSERTED ON (INSERTED.PickSlipNo = PACKDETAIL.PickSlipNo AND
                             INSERTED.CartonNo   = PACKDETAIL.CartonNo AND
                             INSERTED.LabelNo    = PACKDETAIL.LabelNo  AND
                             INSERTED.LabelLine  = PACKDETAIL.LabelLine)
        SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
        IF @n_err <> 0
        BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=90001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PACKDETAIL. (ntrPackDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
        END

      END
      -- Added by YokeBeen on 19-Sep-2003 - End
      
      IF UPDATE(PickSlipNo) OR UPDATE(CartonNo) OR UPDATE(LabelNo) OR UPDATE(LabelLine)   -- KHLim01
      BEGIN
         IF EXISTS(SELECT 1 FROM DELETED
                   WHERE DELETED.CartonNo > 0   -- tlting01
                   AND NOT EXISTS ( SELECT 1 FROM INSERTED
                                      WHERE INSERTED.PickSlipNo = DELETED.PickSlipNo
                                      AND   INSERTED.CartonNo  = DELETED.CartonNo
                                      AND   INSERTED.LabelNo   = DELETED.LabelNo
                                      AND   INSERTED.LabelLine = DELETED.LabelLine
                                     )
                  )
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspGetRight  NULL,             -- facility
                                 NULL,             -- Storerkey
                                 NULL,             -- Sku
                                 'DataMartDELLOG', -- Configkey
                                 @b_success     OUTPUT,
                                 @c_authority   OUTPUT,
                                 @n_err         OUTPUT,
                                 @c_errmsg      OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
                     ,@c_errmsg = 'ntrPackDetailUpdate' + dbo.fnc_RTrim(@c_errmsg)
            END
            ELSE
            IF @c_authority = '1'
            BEGIN
               INSERT INTO dbo.PackDetail_DELLOG ( PickSlipNo, CartonNo, LabelNo, LabelLine, Storerkey, SKU, QTY  )
               SELECT PickSlipNo, CartonNo, LabelNo, LabelLine, Storerkey, SKU, QTY
                  FROM DELETED
                   WHERE DELETED.CartonNo > 0   --tlting01
                   AND NOT EXISTS ( SELECT 1 FROM INSERTED
                                      WHERE INSERTED.PickSlipNo = DELETED.PickSlipNo
                                      AND   INSERTED.CartonNo  = DELETED.CartonNo
                                      AND   INSERTED.LabelNo   = DELETED.LabelNo
                                      AND   INSERTED.LabelLine = DELETED.LabelLine
                                     )

               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Trigger On Table PackDetail Failed. (ntrPackDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
               END
            END
         END
      END
      -- KHLim01 end

     /*-------------------------------------------------------------*/
     /* 16 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters  */
     /*-------------------------------------------------------------*/

     IF UPDATE(ArchiveCop)
     BEGIN
         SELECT @n_continue = 4
     END

     --NJOW02
     IF @n_continue=1 or @n_continue=2
     BEGIN
        IF EXISTS (SELECT 1 FROM DELETED d
                   JOIN storerconfig s WITH (NOLOCK) ON  d.storerkey = s.storerkey
                   JOIN sys.objects sys WITH (NOLOCK) ON sys.type = 'P' AND sys.name = s.Svalue
                   WHERE  s.configkey = 'PackdetailTrigger_SP')
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
     
           EXECUTE dbo.isp_PackdetailTrigger_Wrapper
                     'UPDATE'  --@c_Action
                   , @b_Success  OUTPUT
                   , @n_Err      OUTPUT
                   , @c_ErrMsg   OUTPUT
     
           IF @b_success <> 1
           BEGIN
              SELECT @n_continue = 3
                    ,@c_errmsg = 'ntrPackDetailUpdate ' + RTRIM(LTRIM(ISNULL(@c_errmsg,'')))
           END
     
           IF OBJECT_ID('tempdb..#INSERTED') IS NOT NULL
              DROP TABLE #INSERTED
     
           IF OBJECT_ID('tempdb..#DELETED') IS NOT NULL
              DROP TABLE #DELETED
        END
     END      

     /*-------------------------------------------------------------*/
     /* 16 Feb 2004 WANYT SOS#:18664 Archiving & Archive Parameters  */
     /*-------------------------------------------------------------*/

      --(Wan01) - START
      DECLARE @cur_PD CURSOR
      DECLARE @c_Storerkey_Prev  NVARCHAR(15)
          --  , @c_Storerkey       NVARCHAR(15) --(WL01)
            , @c_PickSlipNo      NVARCHAR(10)
            , @n_CartonNo        INT
            , @c_LabelNo         NVARCHAR(20)
            , @c_LabelLine       NVARCHAR(5)

            , @c_CopyLBLToDropID NVARCHAR(30)

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         SET @c_Storerkey_Prev = ''

         SET @cur_PD =  CURSOR FAST_FORWARD READ_ONLY FOR
                        SELECT PACKDETAIL.PickSlipNo
                              ,PACKDETAIL.CartonNo
                              ,PACKDETAIL.LabelNo
                              ,PACKDETAIL.LabelLine
                              ,PACKDETAIL.Storerkey
                        FROM PACKDETAIL WITH (NOLOCK)
                        JOIN INSERTED   ON (PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo)
                                          AND(PACKDETAIL.CartonNo = INSERTED.CartonNo)
                        WHERE ISNULL(RTRIM(PACKDETAIL.DropID),'') = ''
                        AND   ISNULL(RTRIM(PACKDETAIL.LabelNo),'')<>''
                        ORDER BY PACKDETAIL.Storerkey

         OPEN @cur_PD
         FETCH NEXT FROM @cur_PD INTO @c_PickSlipNo
                                    , @n_CartonNo
                                    , @c_LabelNo
                                    , @c_LabelLine
                                    , @c_Storerkey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @c_Storerkey_Prev <> @c_Storerkey
            BEGIN
               SELECT @c_CopyLBLToDropID = SC.Svalue
               FROM STORERCONFIG SC (NOLOCK)
               WHERE SC.Storerkey = @c_Storerkey
               AND   SC.Configkey = 'PackCopyLabelNoToDropId'
               AND   SC.Svalue = '1'
            END

            IF @c_CopyLBLToDropID = '1'
            BEGIN
               UPDATE PACKDETAIL
               SET PACKDETAIL.DropID = @c_LabelNo
               FROM INSERTED WITH (NOLOCK)
               WHERE PACKDETAIL.PickSlipNo= @c_PickSlipNo
               AND   PACKDETAIL.CartonNo  = @n_CartonNo
               AND   PACKDETAIL.LabelLine = @c_LabelLine

               SET @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(char(250),@n_err)
                  SET @n_err=90014   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SET @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PACKDETAIL. (ntrPackDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
               END
            END

            SET @c_Storerkey_Prev = @c_Storerkey
            FETCH NEXT FROM @cur_PD INTO @c_PickSlipNo
                                       , @n_CartonNo
                                       , @c_LabelNo
                                       , @c_LabelLine
                                       , @c_Storerkey
         END
      END
      --(Wan02) - END

      --(Kc01) - start
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         IF EXISTS(SELECT 1
             FROM   INSERTED
             JOIN   DELETED
               ON   INSERTED.PickSlipNo = DELETED.PickSlipNo
              AND   INSERTED.CartonNo = DELETED.CartonNo
              AND   INSERTED.LabelNo = DELETED.LabelNo
              AND   INSERTED.LabelLine = DELETED.LabelLine
             JOIN   STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey
                    AND STORERCONFIG.ConfigKey = 'AutoShortPick' AND STORERCONFIG.SValue='1'
             WHERE INSERTED.ExpQty < DELETED.ExpQty)
         BEGIN
            SET @c_Pickdetailkey = ''
            SET @n_ShortPackQty = 0
            SELECT @n_ShortPackQty = DELETED.ExpQty - INSERTED.ExpQty
               FROM INSERTED
               JOIN DELETED
               ON (INSERTED.PickSlipNo = DELETED.PickSlipNo AND
                    INSERTED.CartonNo   = DELETED.CartonNo AND
                    INSERTED.LabelNo    = DELETED.LabelNo  AND
                    INSERTED.LabelLine  = DELETED.LabelLine)

            SELECT TOP 1 @c_Pickdetailkey = ISNULL(PK.Pickdetailkey,'')
               FROM INSERTED
               JOIN PACKDETAIL PACKD WITH (NOLOCK)
                  ON PACKD.pickslipno = INSERTED.pickslipno
                  AND PACKD.cartonno = INSERTED.cartonno
                  AND PACKD.labelno = INSERTED.labelno
                  AND PACKD.labelline = INSERTED.labelline
                  AND PACKD.sku = INSERTED.sku
               JOIN PACKHEADER PH WITH (NOLOCK) on (PACKD.pickslipno = PH.pickslipno and PH.Status < '9')
               JOIN ORDERDETAIL OD WITH (NOLOCK) on (PH.orderkey = OD.orderkey and PACKD.sku = OD.sku and OD.openqty >= PACKD.expqty)
               JOIN PICKDETAIL PK WITH (NOLOCK) on (OD.orderkey = PK.orderkey and OD.orderlinenumber = PK.orderlinenumber and PK.Status <= '5')
               order by OD.openqty

            IF @c_Pickdetailkey <> ''
            BEGIN
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET QTY = QTY - @n_ShortPackQty
                  ,UOMQTY = UOMQTY - @n_ShortPackQty,
                  EditDate = GETDATE(),   --tlting
                  EditWho = SUSER_SNAME()
               WHERE Pickdetailkey = @c_Pickdetailkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=90011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PICKDETAIL. (ntrPackDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
               END
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=90012   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Unable To Find Pickdetail to Auto Unallocate. (ntrPackDetailUpdate)"
            END
         END
      END
      --(Kc01) - end

      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
         /*----------------------------------------------------------------------------------*/
         /* 2007-July-26 Wanyt SOS#80943 - Not to Delete Qty = 0 for pre-cartonise - (START) */
         /*                                Where Expqty > 0                                  */
         /*----------------------------------------------------------------------------------*/
        IF EXISTS(SELECT 1 FROM INSERTED WHERE Qty = 0 AND ExpQty = 0)
        BEGIN
             -- NJOW 17-DEC-2008 SOS124169

             IF (SELECT COUNT(SValue)
                        FROM  STORERCONFIG (NOLOCK) JOIN PACKHEADER (NOLOCK) ON (STORERCONFIG.Storerkey = PACKHEADER.Storerkey)
                        JOIN INSERTED ON (PACKHEADER.PickSlipNo = INSERTED.PickSlipNo)
                     WHERE Configkey = 'AssignPackLabelToOrdCfg'
                     AND SValue = '1') > 0
               BEGIN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET PICKDETAIL.DropId = '',
                     EditDate = GETDATE(),   --tlting
                     EditWho = SUSER_SNAME()
                  FROM PICKDETAIL INNER JOIN INSERTED ON (PICKDETAIL.Sku = INSERTED.Sku
                  AND PICKDETAIL.Dropid = INSERTED.LabelNo)
                  WHERE INSERTED.Qty = 0
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=90011   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PICKDETAIL. (ntrPackDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
                  END
            END
            -- END SOS124169

            DELETE PackDetail
            FROM   PACKDETAIL
            JOIN INSERTED ON (INSERTED.PickSlipNo = PACKDETAIL.PickSlipNo  AND
                                INSERTED.CartonNo   = PACKDETAIL.CartonNo AND
                                INSERTED.LabelNo    = PACKDETAIL.LabelNo  AND
                                INSERTED.LabelLine  = PACKDETAIL.LabelLine)
            WHERE INSERTED.Qty = 0
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=90001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Delete Failed On PACKDETAIL. (ntrPackDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
            END
         END
         /*----------------------------------------------------------------------------------*/
         /* 2007-July-26 Wanyt SOS#80943 - Not to Delete Qty = 0 for pre-cartonise - (END)   */
         /*----------------------------------------------------------------------------------*/
      END

      --NJOW01
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
          IF UPDATE(Qty)
          BEGIN
              UPDATE PACKINFO WITH (ROWLOCK)
              SET PACKINFO.Qty = PACKINFO.Qty + (INSERTED.Qty - DELETED.Qty)
              FROM INSERTED
              JOIN DELETED ON INSERTED.PickSlipNo = DELETED.PickSlipNo
                         AND INSERTED.CartonNo = DELETED.CartonNo
                         AND INSERTED.LabelNo = DELETED.LabelNo
                         AND INSERTED.LabelLine = DELETED.LabelLine
            JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno
                          AND INSERTED.CartonNo = PACKINFO.CartonNo
            WHERE INSERTED.Qty <> DELETED.Qty

             IF EXISTS(SELECT 1
                       FROM INSERTED
                      JOIN DELETED ON INSERTED.PickSlipNo = DELETED.PickSlipNo
                                   AND INSERTED.CartonNo = DELETED.CartonNo
                                   AND INSERTED.LabelNo = DELETED.LabelNo
                                   AND INSERTED.LabelLine = DELETED.LabelLine
                       JOIN STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey
                                                 AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1'
                      WHERE INSERTED.Qty <> DELETED.Qty)
            BEGIN
                 UPDATE PACKINFO WITH (ROWLOCK)
                 SET PACKINFO.Weight = PACKINFO.Weight + ((INSERTED.Qty - DELETED.Qty) * Sku.StdGrossWgt),
                     PACKINFO.Cube = PACKINFO.Cube + CASE WHEN ISNULL(CZ.Cube,0) = 0 THEN (INSERTED.Qty - DELETED.Qty) * Sku.StdCube ELSE 0 END
                 FROM INSERTED
                 JOIN DELETED ON INSERTED.PickSlipNo = DELETED.PickSlipNo
                            AND INSERTED.CartonNo = DELETED.CartonNo
                            AND INSERTED.LabelNo = DELETED.LabelNo
                            AND INSERTED.LabelLine = DELETED.LabelLine
               JOIN PACKINFO ON INSERTED.Pickslipno = PACKINFO.Pickslipno
                             AND INSERTED.CartonNo = PACKINFO.CartonNo
               JOIN STORERCONFIG (NOLOCK) ON INSERTED.StorerKey = STORERCONFIG.StorerKey
                                           AND STORERCONFIG.ConfigKey = 'Default_PackInfo' AND STORERCONFIG.SValue='1'
               JOIN STORER (NOLOCK) ON (INSERTED.StorerKey = STORER.StorerKey)
               JOIN SKU (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey AND INSERTED.SKU = SKU.Sku)
               LEFT JOIN CARTONIZATION CZ (NOLOCK) ON (STORER.CartonGroup = CZ.CartonizationGroup AND CZ.CartonType = PACKINFO.CartonType)
               WHERE INSERTED.Qty <> DELETED.Qty
            END
          END
      END

      --WL01 Start
      IF (@n_continue = 1 OR @n_continue = 2) AND (@c_PackCartonGID = 1)
      BEGIN
         
         DECLARE @dt_TimeIn DATETIME, @dt_TimeOut DATETIME
         SET @dt_TimeIn = GETDATE()

         --IF UPDATE(Pickslipno)
         BEGIN
            SELECT @c_CartonGID = CASE WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) <> 0 THEN
                                 CL.UDF01 + RIGHT(REPLICATE('0',CL.LONG) + SUBSTRING(PACKDETAIL.LABELNO,CAST(CL.UDF02 AS INT)
                                ,CAST(CL.UDF03 AS INT)-CAST(CL.UDF02 AS INT)+1)
                                ,CAST(CL.LONG AS INT)-LEN(CL.UDF01))
                                 WHEN ISNULL(CL.SHORT,'N') = 'Y' AND CAST(CL.LONG AS INT) = 0 THEN CL.UDF01 + PACKDETAIL.LABELNO ELSE PACKDETAIL.LABELNO END
            FROM INSERTED
            LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo
            OUTER APPLY (SELECT TOP 1 CL.SHORT, CL.LONG, CL.UDF01, CL.UDF02, CL.UDF03, CL.CODE2 FROM
                         CODELKUP CL WITH (NOLOCK) WHERE (CL.LISTNAME = 'BARCODELEN' AND CL.STORERKEY = PackDetail.STORERKEY AND CL.CODE = 'SUPERHUB' AND
                        (CL.CODE2 = @c_Facility OR CL.CODE2 = '') ) ORDER BY CASE WHEN CL.CODE2 = '' THEN 2 ELSE 1 END ) AS CL 
            WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo  
            AND   PACKDETAIL.LabelNo = INSERTED.LabelNo 

            IF EXISTS (SELECT 1 FROM PACKINFO (NOLOCK) JOIN INSERTED ON PACKINFO.Pickslipno = INSERTED.Pickslipno AND PACKINFO.CartonNo = INSERTED.CartonNo)
            BEGIN
               UPDATE PACKINFO WITH (ROWLOCK)
               SET CartonGID = @c_CartonGID
               FROM PACKINFO 
               JOIN INSERTED ON (PACKINFO.Pickslipno = INSERTED.Pickslipno AND PACKINFO.CartonNo = INSERTED.CartonNo)
            END
            --SET @dt_TimeOut = GETDATE()

            --Debug Start
            --INSERT INTO TRACEINFO (TraceName, TimeIn, [TimeOut], Step1, Step2, Step3, Col1, Col2, Col3)
            --SELECT 'ntrPackDetailUpdate', @dt_TimeIn, @dt_TimeOut, 'Pickslipno', 'CartonNo', 'CartonGID', INSERTED.Pickslipno, INSERTED.CartonNo, @c_CartonGID
            --FROM INSERTED
            --LEFT OUTER JOIN PackDetail with (NOLOCK) ON PackDetail.PickSlipNo = INSERTED.PickSlipNo
            --WHERE PACKDETAIL.PickSlipNo = INSERTED.PickSlipNo  
            --AND   PACKDETAIL.LabelNo = INSERTED.LabelNo 
            --Debug End

         END
      END
      --WL01 End

     IF @n_continue = 3 -- Error occured - Process and return
     BEGIN
         DECLARE @n_IsRDT INT
         EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

         IF @n_IsRDT = 1
         BEGIN
            -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
            -- Instead we commit and raise an error back to parent, let the parent decide

            -- Commit until the level we begin with
            WHILE @@TRANCOUNT > @n_starttcnt
               COMMIT TRAN

            -- Raise error with severity = 10, instead of the default severity 16.
            -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
            RAISERROR (@n_err, 10, 1) WITH SETERROR

            -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
         END
         ELSE
         BEGIN
            SELECT @b_success = 0
            IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt -- Edit by James, @@TRANCOUNT shd always >= @n_starttcnt
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
            EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrPackDetailUpdate"
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         END
     END
     ELSE
     BEGIN
         SELECT @b_success = 1
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
             COMMIT TRAN
         END
     END
 END

GO