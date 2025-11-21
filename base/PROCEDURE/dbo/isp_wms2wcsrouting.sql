SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Trigger:  isp_WMS2WCSRouting                                         */
/* Creation Date: 05-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: AQSACM                                                   */
/*                                                                      */
/* Purpose:  C/R :Transfer of Republic Operations from AS/400 based     */
/*                Systems to WMS Exceed                                 */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-08-2010   Shong     1.1   Prevent Duplicate record added          */
/* 31-05-2012   TLTING01  1.2   Avoid Deadlock issue                    */
/* 15-04-2014   ChewKP    1.3   Extend @n_BoxNo to Numeric (ChewKP01)   */
/* 21-05-2014   Shong     1.4   Do not insert into ORDER_HEADER         */
/*                              If tote id is not numeric               */
/* 22-05-2014   ChewKP    1.5   Fixes (ChewKP02)                        */
/* 24-02-2019   TLTING01  1.6   extend variable length                  */
/* 03-10-2022   MLam      1.7   Fix error when insert to Link Svr (ML01)*/
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_WMS2WCSRouting]
       @c_WCSKey      NVARCHAR(10)
     , @c_StorerKey   NVARCHAR(15)
     , @b_Success     INT        OUTPUT
     , @n_err         INT        OUTPUT
     , @c_errmsg      NVARCHAR(20)  OUTPUT

AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   -- linked server
   SET ANSI_NULLS ON
   SET ANSI_WARNINGS ON
   SET XACT_ABORT ON

 DECLARE  @c_ActionFlag    NVARCHAR(6),
            @c_DtActionFlag      NVARCHAR(6),
            @c_TargetDBName      NVARCHAR(30),   -- TLTING01
            @c_Zone              NVARCHAR(6),
            @n_RowRef            INT,
            @n_SEQNUM_HEADER     INT,
            @n_DtInd             INT,
            @n_BoxNo             NUMERIC(20),  -- (ChewKP01)
            @c_WCSKeyCheck       NVARCHAR(10)

   DECLARE @c_ExecStatements     nvarchar(4000) ,
            @c_ExecArguments     nvarchar(4000)  ,
            @n_continue          int,
            @b_Debug             int,
            @n_starttcnt         int,
            @nCount              int

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
   SET @n_StartTCnt=@@TRANCOUNT
   -- set constant values
   SET @n_DtInd = 0
   -- find Target DB
   SELECT @c_TargetDBName = UPPER(SValue)
   FROM   dbo.StorerConfig WITH (NOLOCK)
   WHERE  CONFIGKEY = 'REPWCSDB'
      AND Storerkey = @c_StorerKey

  -- BEGIN TRAN
   WHILE @@TRANCOUNT > 0    -- ML01
      COMMIT TRAN           -- ML01

 -- Check SourceKey/WCSKEY
   IF ISNULL(RTRIM(@c_WCSKey),'') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_err = 70398
    SET @c_errmsg = 'WCSkey Is Blank'
      GOTO QUIT_SP
   END



   SET @c_WCSKeyCheck = ''
   SET @c_WCSKeyCheck = Substring(@c_WCSKey, PATINDEX ('%[^0]%', @c_WCSKey),len(@c_WCSKey))
   IF LEN(ISNULL(RTRIM(@c_WCSKeyCheck),'')) > 8            BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 70410
      SELECT @c_errmsg = 'WCSKey > 8 Digit'
      GOTO QUIT_SP
   END

   SET @n_SEQNUM_HEADER  = CAST (@c_WCSKeyCheck as INT) -- int cannot cater > 8 digit



   -- insert into order header

   SET @c_ActionFlag = ''
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF (SELECT ISNUMERIC(ToteNo)
          FROM   dbo.WCSRouting  WITH (NOLOCK)
          WHERE  WCSRouting.WCSKey = @c_WCSKey) = 1
      BEGIN
         SELECT @c_ActionFlag   = ISNULL(RTRIM(ActionFlag),''),
                @n_BoxNo   = CAST(ToteNo as NUMERIC(20))   -- (ChewKP01)
         FROM   dbo.WCSRouting  WITH (NOLOCK)
         WHERE  WCSRouting.WCSKey = @c_WCSKey



         IF ISNULL(RTRIM(@c_ActionFlag),'') = ''
         BEGIN
            SET @n_continue = 3
            SET @n_err = 70399
            SET @c_errmsg = 'HD Action is blank'
            GOTO QUIT_SP
         END

         IF ISNULL(RTRIM(@c_ActionFlag),'') = 'I'
          SET @c_ActionFlag = 'INSERT'
         ELSE IF ISNULL(RTRIM(@c_ActionFlag),'') = 'U'
          SET @c_ActionFlag = 'UPDATE'
         ELSE IF ISNULL(RTRIM(@c_ActionFlag),'') = 'D'
          SET @c_ActionFlag = 'DELETE'

         SET @c_ExecStatements = ''
         SET @c_ExecArguments = ''

         --insert into ORDER_HEADER table
         SET @c_ExecStatements =
                N'IF NOT EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_HEADER   '
                 + ' WHERE SEQNUM_HEADER = @n_SEQNUM_HEADER) '
                 + ' INSERT INTO ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_HEADER '
                 + ' ( SEQNUM_HEADER, ACTION, BOXNUMBER, STATE_HCOM)    '
                 + '  VALUES'
                 + ' ( @n_SEQNUM_HEADER,  @c_ActionFlag, @n_BoxNo,''0'' ) '

         IF @b_Debug = 1
         SELECT @c_ExecStatements

         SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(30), ' +
                 '@n_SEQNUM_HEADER INT, ' +
                 '@n_BoxNo NUMERIC(20), ' +   -- (ChewKP01)
                 '@c_ActionFlag NVARCHAR(6) '

         EXEC sp_ExecuteSql @c_ExecStatements
                , @c_ExecArguments
                , @c_TargetDBName
                , @n_SEQNUM_HEADER
                , @n_BoxNo
                , @c_ActionFlag

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 70400
            SET @c_errmsg = 'Insert ORDHD Failed'
            GOTO QUIT_SP
         END


         -- (ChewKP01)
         --Update into ORDER_HEADER table
         INSERT TraceInfo (TraceName , TimeIn , Col1 , Col2 )
         VALUES ( 'WMS2WCS' , GETDATE() , @c_ActionFlag , @n_SEQNUM_HEADER )


         SELECT @nCount = Count (DISTINCT WCSKey)
         FROM dbo.WCSRouting WITH (NOLOCK)
         WHERE ToteNo like CAST(@n_BoxNo AS NVARCHAR(20)) -- (ChewKP02)
         AND Status = '0'



         IF @nCount > 1 AND @c_ActionFlag <> 'DELETE'
         BEGIN

            SET @c_ExecStatements =
                  N'IF EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_HEADER   '
                    + ' WHERE SEQNUM_HEADER = @n_SEQNUM_HEADER) '
                    + ' UPDATE ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_HEADER '
          --+ ' SET ACTION =  ''' + @c_ActionFlag + '''
                    + ' SET ACTION =  ''UPDATE'' '
                    + ' WHERE SEQNUM_HEADER = @n_SEQNUM_HEADER'


            IF @b_Debug = 1
            SELECT @c_ExecStatements

            SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(20), ' +
                    '@n_SEQNUM_HEADER INT, ' +
                    '@n_BoxNo NUMERIC(20), ' +   -- (ChewKP01)
                    '@c_ActionFlag NVARCHAR(6) '

            EXEC sp_ExecuteSql @c_ExecStatements
                   , @c_ExecArguments
                   , @c_TargetDBName
                   , @n_SEQNUM_HEADER
                   , @n_BoxNo
                   , @c_ActionFlag

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 70400
               SET @c_errmsg = 'Insert ORDHD Failed'
               GOTO QUIT_SP
            END

            INSERT TraceInfo (TraceName , TimeIn , Col1 , Col2, col3 )
            VALUES ( 'WMS2WCS' , GETDATE() , @c_ActionFlag , @n_SEQNUM_HEADER, '1' )

         END


         DECLARE WCS_CUR CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT ROWREF, ISNULL(ActionFlag,''),  ISNULL(Zone,'')
         FROM dbo.WCSRoutingDetail  WITH (NOLOCK)
         WHERE WCSRoutingDetail.WCSKEY = @c_WCSKey
         Order by ROWREF

         OPEN WCS_CUR

         FETCH NEXT FROM WCS_CUR INTO @n_RowRef, @c_DtActionFlag, @c_Zone
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            SET @n_DtInd = 1
            IF @b_Debug = 1
               select '@n_RowRef=',@n_RowRef,'@c_DtActionFlag=',@c_DtActionFlag,'@c_Zone=',@c_Zone

            IF ISNULL(RTRIM(@c_DtActionFlag),'') = ''
            BEGIN
               SET @n_continue = 3
               SET @n_err = 70401
               SET @c_errmsg = 'DT ActionFlag is blank'
               GOTO QUIT_SP
            END

            IF ISNULL(RTRIM(@c_DtActionFlag),'') = 'I'
             SET @c_DtActionFlag = 'INSERT'
            ELSE IF ISNULL(RTRIM(@c_DtActionFlag),'') = 'U'
             SET @c_DtActionFlag = 'UPDATE'
            ELSE IF ISNULL(RTRIM(@c_DtActionFlag),'') = 'D'
             SET @c_DtActionFlag = 'DELETE'


            SET @c_ExecStatements = ''
            SET @c_ExecArguments = ''

            --insert into ORDER_DETAIL table
            SET @c_ExecStatements =
                 N'IF NOT EXISTS(SELECT 1 FROM ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_DETAIL   '
                  + ' WHERE SEQNUM_DETAIL = @n_RowRef AND SEQNUM_HEADER = @n_SEQNUM_HEADER ) '
                  + ' INSERT INTO ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_DETAIL '
                  + ' ( SEQNUM_DETAIL,  SEQNUM_HEADER, ACTION,    '
                  + '  STATION,  STATE_HCOM) '
                  + '  VALUES '
                  + '  (@n_RowRef,  @n_SEQNUM_HEADER,  @c_DtActionFlag,  '
                  + '  @c_Zone,     ''0'' )'

            IF @b_Debug = 1
               SELECT @c_ExecStatements

            SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(20), ' +
                                    '@n_SEQNUM_HEADER INT, ' +
                                    '@n_RowRef INT, ' +
                                    '@c_Zone NVARCHAR(6), ' +
                                    '@c_DtActionFlag NVARCHAR(6) '

            EXEC sp_ExecuteSql @c_ExecStatements
                  , @c_ExecArguments
                  , @c_TargetDBName
                  , @n_SEQNUM_HEADER
                  , @n_RowRef
                  , @c_Zone
                  , @c_DtActionFlag

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 70402
               SET @c_errmsg = 'Insert ORDDT Failed'
               GOTO QUIT_SP
            END

         FETCH NEXT FROM WCS_CUR INTO @n_RowRef, @c_DtActionFlag, @c_Zone
         END -- WHILE @@FETCH_STATUS <> -1
         CLOSE WCS_CUR
         DEALLOCATE WCS_CUR

         -- IF NO ERROR, UPDATE to '10' and date inserted value to current date
         SET @c_ExecStatements = ''
         SET @c_ExecArguments = ''

         --Update ORDER_HEADER
         SET @c_ExecStatements =  N'UPDATE ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_HEADER   '
                                 + ' SET STATE_HCOM = ''10'', DATE_INSERTED = Getdate() '
                  -- ' SET DATE_INSERTED = Getdate() '
                                 + ' WHERE SEQNUM_HEADER = @n_SEQNUM_HEADER AND STATE_HCOM = ''0'' '

         IF @b_Debug = 1
            SELECT @c_ExecStatements

         SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(20), ' +
                                 '@n_SEQNUM_HEADER INT '

         EXEC sp_ExecuteSql @c_ExecStatements
                     , @c_ExecArguments
                     , @c_TargetDBName
                     , @n_SEQNUM_HEADER

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 70403
            SET @c_errmsg = 'Update ORDDT Failed'
            GOTO QUIT_SP
         END

         SET @c_ExecStatements = ''
         SET @c_ExecArguments = ''

         --update ORDER_DETAIL
         IF @n_DtInd > 0
         BEGIN
            SET @c_ExecStatements =  N'UPDATE ' + ISNULL(RTRIM(@c_TargetDBName),'') + '.dbo.ORDER_DETAIL   '
                    + ' SET STATE_HCOM = ''10'', DATE_INSERTED = Getdate() '
                    --+ ' SET DATE_INSERTED = Getdate() '
                    + ' WHERE SEQNUM_HEADER = @n_SEQNUM_HEADER AND STATE_HCOM = ''0'' '

            IF @b_Debug = 1
               SELECT @c_ExecStatements

            SET @c_ExecArguments = N'@c_TargetDBName NVARCHAR(20), ' +
                                    '@n_SEQNUM_HEADER INT'

            EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @c_TargetDBName
                    , @n_SEQNUM_HEADER

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err = 70404
               SET @c_errmsg = 'Update ORDDT Failed'
               GOTO QUIT_SP
            END
         END

      END
   END
   SET ROWCOUNT 0

   QUIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
       SELECT @b_success = 0
       IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
       BEGIN
          ROLLBACK TRAN
       END
       ELSE
       BEGIN
          WHILE @@TRANCOUNT > @n_starttcnt
          BEGIN
             COMMIT TRAN
          END
          WHILE @@TRANCOUNT < @n_starttcnt   -- ML01
          BEGIN                              -- ML01
             BEGIN TRAN                      -- ML01
          END                                -- ML01
       END
       EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspInsertWCSRouting'
       --RAISERROR @n_ErrNo @c_ErrMsg
       RETURN
   END
   ELSE
   BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       WHILE @@TRANCOUNT < @n_starttcnt      -- ML01
       BEGIN                                 -- ML01
          BEGIN TRAN                         -- ML01
       END                                   -- ML01
       RETURN
   END
   IF @b_Debug = 1
       SELECT '@b_success',@b_success,'@n_continue',@n_continue,'@n_err',@n_err,'@c_errmsg',@c_errmsg

   RETURN
END

GO