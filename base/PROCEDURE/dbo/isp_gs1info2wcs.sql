SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GS1Info2WCS                                    */
/* Creation Date: 18-Jan-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose:  SOS#158576 - GS1 Label printing for IDSUS Titan.           */
/*           @c_LoadKey = '' >> Calling from RDT                        */
/*           @c_OrderKey = '' >> Calling from WMS                       */
/*                                                                      */
/* Data Stream: 0605                                                    */
/*                                                                      */
/* Called By: Triggered upon the 1st carton packed through RDT function */
/*                                                                      */
/* Output Parameters: @b_Success        - Success Flag  = 0             */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/*              Vicky           Fixed RDT Schema Mistake                */
/* 03-Jun-2010  ChewKP    1.1   SOS#173479 Add Additional Flag for      */
/*                              LocCategory Filtering (ChewKP01)        */
/* 21-Jun-2010  MCTang    1.1   SOS#182871 Filter by LocationCategory   */
/*                              = "VAS" (MC01)                          */
/* 11-Oct-2010  NJOW01    1.3   Return success status even no data found*/
/* 26-Jan-2011  Leong     1.4   Standardize LineText field length       */
/*                              (Leong01)                               */
/* 2014-Mar-21  TLTING    1.5   SQL20112 Bug                            */
/************************************************************************/

CREATE PROC [dbo].[isp_GS1Info2WCS] (
      @c_LoadKey      NVARCHAR(10)     = ''
    , @c_DropID       NVARCHAR(18)     = ''
    , @c_OrderKey     NVARCHAR(10)     = ''
    , @c_CartonNo     int          = 0
    , @b_debug        int          = 0
    , @b_Success      int          = 1 OUTPUT
    , @b_LocFilter    int          = 0 -- (ChewKP01)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   IF @b_debug = 1 or @b_debug = 2
   BEGIN
      SELECT 'START Time: ', GETDATE()
   END

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/

   DECLARE @n_StartTCnt             int
         , @n_continue              int
         , @c_errmsg                NVARCHAR(255)
         , @n_err                   int
         , @c_ExecStatements        nvarchar(4000)
         , @c_ExecArguments         nvarchar(4000)

   DECLARE @c_DataStream            NVARCHAR(10)
         , @c_LabelNo               NVARCHAR(20)
         , @c_Header                NVARCHAR(1)
         , @c_Authority_WMSWCSGS1   NVARCHAR(1)
         , @c_StorerKey             NVARCHAR(15)
         , @c_Prev_StorerKey        NVARCHAR(15)
         , @c_Facility              NVARCHAR(5)
         , @c_Prev_Facility         NVARCHAR(5)
         , @c_LocationCategory      NVARCHAR(10)
         , @c_LocationCategory2     NVARCHAR(10) -- (MC01)
         , @c_Configkey             NVARCHAR(30)
         , @c_TableName             NVARCHAR(30)
         , @c_Module                NVARCHAR(1)

   SELECT  @n_StartTCnt = @@TRANCOUNT

/*
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
*/
   SET @c_ExecStatements      = ''
   SET @c_ExecArguments       = ''
   SET @n_continue            = 0
   SET @c_errmsg              = ''
   SET @b_success             = 0
   SET @n_err                 = 0

   SET @c_DataStream          = '0605'
   SET @c_Header              = 0
   SET @c_Authority_WMSWCSGS1 = '0'
   SET @c_Prev_StorerKey      = ''
   SET @c_Prev_Facility       = ''
   SET @c_LocationCategory    = 'HVCP'
   SET @c_LocationCategory2   = 'VAS'   -- (MC01)
   SET @c_StorerKey           = ''
   SET @c_Facility            = ''
   SET @c_Configkey           = 'WMSWCSGS1'
   SET @c_TableName           = 'WMSWCSGS1'

   IF ISNULL(RTRIM(@c_OrderKey),'') <> '' AND ISNULL(RTRIM(@c_LoadKey),'') = '' AND ISNULL(RTRIM(@c_DropID),'') = ''
   BEGIN
      SET @c_Module = 'W'
   END
   ELSE
   BEGIN
      SET @c_Module = 'R'
   END

   IF @b_debug = 1
   BEGIN
      SELECT '@c_Module: ', @c_Module
   END

   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   IF ISNULL(RTRIM(@c_Module),'') = 'R'
   BEGIN
      IF @b_LocFilter = 0 -- (ChewKP01)
      BEGIN
         DECLARE RDT_GS1_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT DropIdDetail.ChildID, Orders.OrderKey, Orders.StorerKey, Orders.Facility
         FROM DropId DropId WITH (NOLOCK)
         JOIN DropIdDetail DropIdDetail WITH (NOLOCK) ON ( DropId.DropID = DropIdDetail.DropID )
         JOIN PackDetail PackDetail WITH (NOLOCK) ON ( DropIdDetail.ChildID = PackDetail.LabelNo )
         JOIN PackHeader PackHeader WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
         JOIN Orders Orders WITH (NOLOCK) ON ( Orders.Orderkey = PackHeader.Orderkey )
         JOIN Loc Loc WITH (NOLOCK) ON ( DropId.DropLoc = Loc.Loc )
         WHERE DropId.DropId = ISNULL(RTRIM(@c_DropID),'')
         AND DropId.LabelPrinted = 'Y'
         AND DropId.DropIDType = 'C'
         AND (Loc.LocationCategory = ISNULL(RTRIM(@c_LocationCategory),'')
              OR Loc.LocationCategory = ISNULL(RTRIM(@c_LocationCategory2),'')) -- (MC01)
         AND PackHeader.LoadKey = ISNULL(RTRIM(@c_LoadKey),'')
      END
      ELSE
      BEGIN
         DECLARE RDT_GS1_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT DropIdDetail.ChildID, Orders.OrderKey, Orders.StorerKey, Orders.Facility
         FROM DropId DropId WITH (NOLOCK)
         JOIN DropIdDetail DropIdDetail WITH (NOLOCK) ON ( DropId.DropID = DropIdDetail.DropID )
         JOIN PackDetail PackDetail WITH (NOLOCK) ON ( DropIdDetail.ChildID = PackDetail.LabelNo )
         JOIN PackHeader PackHeader WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
         JOIN Orders Orders WITH (NOLOCK) ON ( Orders.Orderkey = PackHeader.Orderkey )
         JOIN Loc Loc WITH (NOLOCK) ON ( DropId.DropLoc = Loc.Loc )
         WHERE DropId.DropId = ISNULL(RTRIM(@c_DropID),'')
         AND DropId.LabelPrinted = 'Y'
         AND DropId.DropIDType = 'C'
         AND PackHeader.LoadKey = ISNULL(RTRIM(@c_LoadKey),'')
      END

      OPEN RDT_GS1_Rec_Cur

      FETCH NEXT FROM RDT_GS1_Rec_Cur INTO @c_LabelNo, @c_OrderKey, @c_StorerKey, @c_Facility

      IF @@FETCH_STATUS = -1  -- NJOW01
      BEGIN
         SELECT @b_success = 1
      END

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN

         IF @b_debug = 1
         BEGIN
            SELECT '@c_LabelNo: ' + ISNULL(RTRIM(@c_LabelNo),'')
                 + ', @c_OrderKey: ' + ISNULL(RTRIM(@c_OrderKey),'')
                 + ', @c_StorerKey: ' + ISNULL(RTRIM(@c_StorerKey),'')
                 + ', @c_Facility: ' + ISNULL(RTRIM(@c_Facility),'')
         END

         IF (@c_Prev_StorerKey <> @c_StorerKey) OR (@c_Prev_Facility <> @c_Facility)
         BEGIN

            SET @c_Authority_WMSWCSGS1 = '0'

            EXECUTE dbo.nspGetRight
                     @c_Facility,
                     @c_StorerKey,
                     '',
                     @c_Configkey,
                     @b_success              OUTPUT,
                     @c_authority_WMSWCSGS1  OUTPUT,
                     @n_err                  OUTPUT,
                     @c_errmsg               OUTPUT

            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62918
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Retrieve of Right (PICKCFMITF) Failed (isp_GS1Info2WCS) ( '
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               BREAK
            END

            IF @b_debug = 1
            BEGIN
               SELECT '@c_Authority_WMSWCSGS1: ' + @c_Authority_WMSWCSGS1
            END

         END

         IF @c_Authority_WMSWCSGS1 = '1'
         BEGIN

            IF @c_Header = 0
            BEGIN
               INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
               VALUES ('<?xml version="1.0" encoding="UTF-8" standalone="no"?>', @@SPID)

               INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
               VALUES ('<label>', @@SPID)

               SET @c_Header = 1
            END

            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES ('<variable name="1">', @@SPID)

            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES ('<WMS_ORD_NO>' + ISNULL(RTRIM(@c_OrderKey),'') + '</WMS_ORD_NO>', @@SPID)

            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES ('<LOAD_NO>' + ISNULL(RTRIM(@c_LoadKey),'') + '</LOAD_NO>', @@SPID)

            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES ('<GS1_NO>' + ISNULL(RTRIM(@c_LabelNo),'') + '</GS1_NO>', @@SPID)

            INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
            VALUES ('</variable>', @@SPID)

         END --IF @c_authority_WMSWCSGS1 = '1'

         SET @c_Prev_StorerKey = @c_StorerKey
         SET @c_Prev_Facility = @c_Facility

         FETCH NEXT FROM RDT_GS1_Rec_Cur INTO @c_LabelNo, @c_OrderKey, @c_StorerKey, @c_Facility
      END -- END WHILE (@@FETCH_STATUS <> -1)

      CLOSE RDT_GS1_Rec_Cur
      DEALLOCATE RDT_GS1_Rec_Cur

      IF @c_Header = 1
      BEGIN
         INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
         VALUES ('</label>', @@SPID)
      END
   END
   ELSE --IF ISNULL(RTRIM(@c_Module),'') = 'W'
   BEGIN

      IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') = ''
      BEGIN
         CREATE TABLE #TempGSICartonLabel_XML
                  ( SeqNo int IDENTITY(1,1),            -- Temp table's PrimaryKey
                    LineText NVARCHAR(1000)              -- XML column -- Leong01
                  )
         CREATE INDEX Seq_ind ON #TempGSICartonLabel_XML (SeqNo)
      END

      IF NOT EXISTS( SELECT 1 FROM Transmitlog3 WITH (NOLOCK)
                     WHERE TableName = ISNULL(RTRIM(@c_TableName),'')
                     AND Key1 = ISNULL(RTRIM(@c_OrderKey),'')
                     AND Key2 = ISNULL(RTRIM(@c_CartonNo),'') )
      BEGIN

         DECLARE WMS_GS1_Rec_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PackDetail.LabelNo, Orders.StorerKey, Orders.Facility, LoadPlan.LoadKey
         FROM PACKHEADER PackHeader with (index =Idx_PACKHEADER_orderkey, NOLOCK)
         JOIN PACKDETAIL PackDetail WITH (NOLOCK) ON ( PackHeader.PickSlipNo = PackDetail.PickSlipNo )
         JOIN Orders Orders WITH (NOLOCK) ON ( Orders.Orderkey = PackHeader.Orderkey )
         JOIN Loadplan Loadplan WITH (NOLOCK) ON ( Loadplan.LoadKey = PackHeader.LoadKey )
         WHERE PackHeader.Orderkey = ISNULL(RTRIM(@c_OrderKey), '')
         AND ( PackDetail.CartonNo = ISNULL(RTRIM(@c_CartonNo),0) OR ISNULL(RTRIM(@c_CartonNo),0) = 0  )
         AND ( IsNumeric(LoadPlan.UserDefine10) = 1 )

         OPEN WMS_GS1_Rec_Cur

         FETCH NEXT FROM WMS_GS1_Rec_Cur INTO @c_LabelNo, @c_StorerKey, @c_Facility, @c_LoadKey

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            IF @b_debug = 1
            BEGIN
               SELECT '@c_LabelNo: ' + ISNULL(RTRIM(@c_LabelNo),'')
                    + ', @c_LoadKey: ' + ISNULL(RTRIM(@c_LoadKey),'')
                    + ', @c_StorerKey: ' + ISNULL(RTRIM(@c_StorerKey),'')
                    + ', @c_Facility: ' + ISNULL(RTRIM(@c_Facility),'')
            END

            IF (@c_Prev_StorerKey <> @c_StorerKey) OR (@c_Prev_Facility <> @c_Facility)
            BEGIN

               SET @c_Authority_WMSWCSGS1 = '0'

               EXECUTE dbo.nspGetRight
                        @c_Facility,
                        @c_StorerKey,
                        '',
                        @c_Configkey,
                        @b_success              OUTPUT,
                        @c_authority_WMSWCSGS1  OUTPUT,
                        @n_err                  OUTPUT,
                        @c_errmsg               OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62918
                  SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                   + ': Retrieve of Right (PICKCFMITF) Failed (isp_GS1Info2WCS) ( '
                                   + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                  BREAK
               END

               IF @b_debug = 1
               BEGIN
                  SELECT '@c_Authority_WMSWCSGS1: ' + @c_Authority_WMSWCSGS1
               END

            END -- IF (@c_Prev_StorerKey <> @c_StorerKey) OR (@c_Prev_Facility <> @c_Facility)


            IF @c_Authority_WMSWCSGS1 = '1'
            BEGIN
               IF @c_Header = 0
               BEGIN
                  INSERT INTO #TempGSICartonLabel_XML (LineText)
                  VALUES ('<?xml version="1.0" encoding="UTF-8" standalone="no"?>')

                  INSERT INTO #TempGSICartonLabel_XML (LineText)
                  VALUES ('<label>')

                  SET @c_Header = 1
               END

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('<variable name="1">')

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('<WMS_ORD_NO>' + ISNULL(RTRIM(@c_OrderKey),'') + '</WMS_ORD_NO>')

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('<LOAD_NO>' + ISNULL(RTRIM(@c_LoadKey),'') + '</LOAD_NO>')

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('<GS1_NO>' + ISNULL(RTRIM(@c_LabelNo),'') + '</GS1_NO>')

               INSERT INTO #TempGSICartonLabel_XML (LineText)
               VALUES ('</variable>')

            END --IF @c_Authority_WMSWCSGS1 = '1'

            SET @c_Prev_StorerKey = @c_StorerKey
            SET @c_Prev_Facility = @c_Facility

            FETCH NEXT FROM WMS_GS1_Rec_Cur INTO @c_LabelNo, @c_StorerKey, @c_Facility, @c_LoadKey
         END -- END WHILE (@@FETCH_STATUS <> -1)

         CLOSE WMS_GS1_Rec_Cur
         DEALLOCATE WMS_GS1_Rec_Cur

         IF @c_Header = 1
         BEGIN
            INSERT INTO #TempGSICartonLabel_XML (LineText)
            VALUES ('</label>')

            EXEC dbo.ispGenTransmitLog3 @c_TableName
                                       , @c_OrderKey
                                       , @c_CartonNo
                                       , ''
                                       , @c_LabelNo
                                       , @b_success OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT
            IF @b_success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62918
               SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))
                                + ': Insert Transmitlog3 fail (isp_GS1Info2WCS) ( '
                                + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END

            -- Update the transmitflag = '9'
            Update TransmitLog3 with (RowLock)
            SET TransmitFlag = '9',
                Trafficcop = NULL
            WHERE TableName = ISNULL(RTRIM(@c_TableName),'')
            AND Key1 = ISNULL(RTRIM(@c_OrderKey),'')
            AND Key2 = ISNULL(RTRIM(@c_CartonNo),'')
            AND TransmitFlag = '0'

         END
      END
   END --IF ISNULL(RTRIM(@c_Module),'') = 'W'

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @c_Header = 1
   BEGIN
      SET @b_Success = 1
   END

   IF ISNULL(RTRIM(@c_Module),'') = 'W'
   BEGIN
      SELECT SeqNo, LineText
      FROM #TempGSICartonLabel_XML
   END

   IF @b_debug = 1 or @b_debug = 2
   BEGIN
      SELECT 'END Time: ', GETDATE()
   END

END
/*********************************************/
/* Cursor Loop - XML Data Insertion (End)    */
/*********************************************/

GO