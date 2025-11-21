SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_TCP_CLOSE_PALLET_IN                            */
/* Creation Date: 11-11-2011                                            */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: Picking from Bulk to Induction                              */
/*          RedWerks to WMS Exceed                                      */
/*                                                                      */
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/* PVCS Version: 1.2 (Unicode)                                          */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 31-01-2012   ChewKP    1.1   Validate Duplicate PalletID (ChewKP01)  */
/* 07-02-2012   James     1.2   Stamp LabelPrinted = 'Y' (james01)      */
/* 08-02-2012   ChewKP    1.3   Get Loadkey (ChewKP02)                  */
/* 17-02-2012   ChewKP    1.4   Update Status = '1' before process      */
/*                              (ChewKP03)                              */
/* 14-03-2012   ChewKP    1.5   Update PackInfo.Weight (ChewKP04)       */
/* 21-03-2012   ChewKP    1.6   Add DropIDDetail.LabelPrinted (ChewKP05)*/
/* 05-Apr-2012  Shong     1.7   Change LPN# Length to 20 chars          */
/* 06-Apr-2012  James     1.8   Temp change LPN# Len 18 chars (james02) */
/* 07-Apr-2012  SHong     1.9   Trigger Agile Rate Request              */
/* 19-Apr-2012  Ung       2.0   Enlarge data string (ung01)             */
/*                              Stamp DropID.LoadKey (ung01)            */
/* 01-May-2012  James     2.1   Bug fix (james03)                       */
/* 14-May-2012  James     2.2   Insert Master Pack child GS1 label into */
/*                              DropIDDetail (james04)                  */
/* 27-JUL-2012  ChewKP    2.3   SOS#249595 Update LoadPlanDetail for    */
/*                              Weight and Cube (ChewKP06)              */
/* 10-OCT-2013  YTWan     1.2   SOS#291410-Change INT to FLOAT - (Wan01)*/
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_TCP_CLOSE_PALLET_IN]
                @c_MessageNum  NVARCHAR(10)
              , @b_Debug      INT
              , @b_Success    INT        OUTPUT
              , @n_Err        INT        OUTPUT
              , @c_ErrMsg     NVARCHAR(250)  OUTPUT

AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT
         , @n_StartTCnt          INT

   DECLARE @n_SerialNo           INT
         , @c_Status             CHAR(1)
         , @c_DataString         NVARCHAR(Max) -- (ung01)
         , @c_MessageType        NVARCHAR(15)
         , @c_MessageNumber      NVARCHAR(8)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Facility           NVARCHAR(5)
         , @c_LPNNo              NVARCHAR(20)  -- (shong01)
         , @c_LaneNumber         NVARCHAR(10)
         , @c_LoadKey            NVARCHAR(10)
         , @c_PickSlipNo         NVARCHAR(10)
         , @c_CartonLine         NVARCHAR(5)
         , @c_GS1Label           NVARCHAR(20)
         , @f_Weight             REAL         -- (ChewKP04)
         , @c_Weight             NVARCHAR(10)  -- (ChewKP04)
         , @n_CartonNo           INT          -- (ChewKP04)
         , @c_AgileProcess       CHAR(1)
         , @c_ChildGS1Label      NVARCHAR(20)  -- (james04)
         , @cOrderKey            NVARCHAR(10)  -- (ChewKP06)
         , @nTotWeight           FLOAT        -- (ChewKP06)  --(Wan01) 
         , @nTotCube             FLOAT        -- (ChewKP06)  --(Wan01)
         , @nTotCartons          INT          -- (ChewKP06) 
         , @cMBOLKey             NVARCHAR(10)  -- (ChewKP06) 
         , @cLoadKey             NVARCHAR(10)  -- (ChewKP06) 
         , @cPickSlipNo          NVARCHAR(10)  -- (ChewKP06) 
         , @nWeight              FLOAT        -- (ChewKP06)  --(Wan01)  
         , @cCartonType          NVARCHAR(10)  -- (ChewKP06)  
         , @nCube                FLOAT        -- (ChewKP06)  --(Wan01)
         , @nCartonNo            INT          -- (ChewKP06)  
   
   SET @c_AgileProcess ='0'

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0
   SET @n_StartTCnt = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN WCS_BULK_PICK

   SET @c_ErrMsg           = ''
   SET @c_Status           = '9'
   SET @n_SerialNo         = 0
   SET @c_DataString       = ''
   SET @c_MessageType      = ''
   SET @c_MessageNumber    = ''
   SET @c_StorerKey        = ''
   SET @c_Facility         = ''
   SET @c_LPNNo            = ''
   SET @c_LaneNumber       = ''
   SET @c_GS1Label         = ''
   SET @c_LoadKey          = ''
   SET @c_PickSlipNo       = ''
   SET @f_Weight           = 0   -- (ChewKP04)
   SET @c_Weight           = ''  -- (ChewKP04)
   SET @n_CartonNo         = 0   -- (ChewKP04)



   SELECT @n_SerialNo   = SerialNo
        , @c_DataString = ISNULL(RTRIM(DATA), '')
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE  MessageNum     = @c_MessageNum
   AND    MessageType   = 'RECEIVE'
   AND    Status        = '0'

   IF ISNULL(RTRIM(@n_SerialNo),'') = ''
   BEGIN
      IF @b_Debug = 1
      BEGIN
         SELECT 'Nothing to process. MessageNum = ' + @c_MessageNum
      END

      RETURN
   END

   IF @b_Debug = 1
   BEGIN
      SELECT '@n_SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo)
           + ', @c_Status : ' + @c_Status
           + ', @c_DataString : ' + @c_DataString
   END

   -- (ChewKP03)
   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK)
   SET Status = '1'
   WHERE SerialNo = @n_SerialNo

   IF ISNULL(RTRIM(@c_DataString),'') = ''
   BEGIN
      SET @n_Continue = 3
      SET @c_Status = '5'
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
      GOTO QUIT_SP
   END

   DECLARE @n_Position   INT
   DECLARE @c_RecordLine NVARCHAR(512)
   DECLARE @c_Delimited  CHAR(1)
   DECLARE @c_LineText   NVARCHAR(512)
          ,@n_SeqNo      INT

   DECLARE @tRecord TABLE (SeqNo INT IDENTITY(1,1), LineText NVARCHAR(512))

   --SET @c_Delimited = '<CR>' -- CHAR(13)
   SET @c_Delimited = CHAR(13)

   SET @c_DataString = @c_DataString + CHAR(13)

--   IF RIGHT(RTRIM(@c_DataString) ,2) <> @c_Delimited
--       SET @c_DataString = @c_DataString + @c_Delimited

   SET @n_Position = CHARINDEX(CHAR(13), @c_DataString)
   WHILE @n_Position <> 0
   BEGIN
       SET @c_RecordLine = LEFT(@c_DataString, @n_Position - 1)

       INSERT INTO @tRecord
       VALUES
         (
           CAST(@c_RecordLine AS NVARCHAR(512))
         )

       SET @c_DataString = STUFF(@c_DataString, 1, @n_Position ,'')
       SET @n_Position = CHARINDEX(CHAR(13), @c_DataString)
   END


   DECLARE CUR_LINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SeqNo, LineText FROM @tRecord
   ORDER BY SeqNo

   OPEN CUR_LINE

   FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText
   WHILE @@FETCH_STATUS <> -1
   BEGIN

    IF @n_SeqNo = 1
    BEGIN
         SET @c_MessageType      = RTRIM(SubString(@c_LineText,   1,  15))
         SET @c_MessageNumber    = RTRIM(SubString(@c_LineText,  16,   8))
         SET @c_StorerKey        = RTRIM(SubString(@c_LineText,  24,  15))
         SET @c_Facility         = RTRIM(SubString(@c_LineText,  39,   5))
         SET @c_LPNNo            = RTRIM(SubString(@c_LineText,  44,  18))    -- (james02)
         SET @c_LaneNumber       = RTRIM(SubString(@c_LineText,  62,  10))

         -- (ChewKP01)
         IF EXISTS (SELECT 1 FROM DROPID WITH (NOLOCK) WHERE Dropid = @c_LPNNo)
         BEGIN
            SET @n_Continue = 3
            SET @c_Status = '5'
            SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
            SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error: Insert DropID Table. PalletID Exist. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
            GOTO QUIT_SP
         END



         IF NOT EXISTS(SELECT 1 FROM DROPID WITH (NOLOCK) WHERE Dropid = @c_LPNNo)
         BEGIN
            INSERT INTO Dropid
            (
             Dropid,             Droploc,             AdditionalLoc,
             DropIDType,         LabelPrinted,        ManifestPrinted,
             [Status],           Loadkey,             PickSlipNo
            )
            VALUES
            (
             @c_LPNNo,             @c_LaneNumber,             '',
             'PALLET',             'Y',                      'N',    -- (james01)
             '0',                   '',                        ''
            )
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert DropID Table. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END

    END
    ELSE
    BEGIN
         SET @c_CartonLine       = RTRIM(SubString(@c_LineText,   1,  5))
         SET @c_GS1Label         = RTRIM(SubString(@c_LineText,   6, 20))
         SET @c_Weight           = RTRIM(SubString(@c_LineText,   26, 8))

/* --(ung01)
         IF NOT EXISTS(SELECT 1 FROM PackDetail pd WITH (NOLOCK)
                       WHERE pd.StorerKey = @c_StorerKey
                       AND pd.LabelNo = @c_GS1Label)
         BEGIN
            IF ISNULL(RTRIM(@c_LoadKey), '') = ''
            BEGIN
               SELECT TOP 1
                     @c_LoadKey = O.LoadKey
                    ,@c_PickSlipNo = PackD.PickSlipNo
                    ,@n_CartonNo   = PackD.CartonNo -- (ChewKP04)
               FROM PickDetail PD WITH (NOLOCK)
               INNER JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
               INNER JOIN PackDetail PackD WITH (NOLOCK) ON (PackD.PickSlipNo = PD.PickSlipNo)
               WHERE PackD.LabelNo = @c_GS1Label

               UPDATE DROPID WITH (ROWLOCK)
                  SET PickSlipNo = @c_PickSlipNo,
                      LoadKey    = @c_LoadKey,
                      TrafficCop = NULL,
                      EditDate = GETDATE(),
                      EditWho = 'WCS',
                      LabelPrinted = 'Y' -- (james01)
               WHERE Dropid = @c_LPNNo
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'

                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update DropID Table. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  GOTO QUIT_SP
               END
            END
         END
         ELSE -- (ChewKP02)
         BEGIN
            SELECT TOP 1
                  @c_LoadKey = O.LoadKey
                 ,@c_PickSlipNo = PackD.PickSlipNo
                 ,@n_CartonNo   = PackD.CartonNo -- (ChewKP04)
            FROM PickDetail PD WITH (NOLOCK)
            INNER JOIN Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
            INNER JOIN PackDetail PackD WITH (NOLOCK) ON (PackD.PickSlipNo = PD.PickSlipNo)
            WHERE PackD.LabelNo = @c_GS1Label

*/

         -- Get LoadKey for normal carton (ung01)
         -- IF @c_LoadKey = ''      -- commented by james03
         -- BEGIN                   -- commented by james03
            -- Get LoadKey for normal carton (ung01)
            SELECT TOP 1
               @c_LoadKey = PH.LoadKey,
               @c_PickSlipNo = PH.PickSlipNo, 
               @n_CartonNo   = PD.CartonNo
            FROM dbo.PackHeader PH WITH (NOLOCK)
               INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PD.LabelNo = @c_GS1Label

            -- Get LoadKey for master carton (which contain children) (ung01)
            IF @c_LoadKey = ''
               SELECT TOP 1
                  @c_LoadKey = PH.LoadKey,
                  @c_PickSlipNo = PH.PickSlipNo, 
                  @n_CartonNo   = PD.CartonNo
               FROM dbo.PackHeader PH WITH (NOLOCK)
                  INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
               WHERE PD.RefNo2 = @c_GS1Label

            IF @c_LoadKey <> ''
            BEGIN
               UPDATE DROPID WITH (ROWLOCK)
                  SET LoadKey    = @c_LoadKey,
                      TrafficCop = NULL,
                      EditDate = GETDATE(),
                      EditWho = 'WCS'
               WHERE Dropid = @c_LPNNo
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @c_Status = '5'

                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update DropID Table. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                  GOTO QUIT_SP
               END
            END
         --END    -- commented by james03
         --END

         IF NOT EXISTS(SELECT 1 FROM DropidDetail dd (NOLOCK)
                       WHERE dd.Dropid = @c_LPNNo
                       AND   dd.ChildId = @c_GS1Label)
         BEGIN
            INSERT INTO DROPIDDETAIL (Dropid, ChildId, AddWho, LabelPrinted)  -- (ChewKP05)
            VALUES (@c_LPNNo, @c_GS1Label, 'WCS', 'Y')    -- (ChewKP05)
            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert DropIDDetail Table. GS1#: ' + CONVERT(VARCHAR, @c_GS1Label) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END
            
            -- Check if it is Master Pack then we need to insert its child gs1 label as childid    (james04)
            IF EXISTS (SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK) 
                       JOIN dbo.DropID D WITH (NOLOCK) ON PD.Refno = D.DropID AND D.DropIDType = 'MASTER'
                       WHERE PD.StorerKey = @c_StorerKey
                       AND   PD.Refno2 = @c_GS1Label)
            BEGIN
            DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
            SELECT DISTINCT LabelNO FROM dbo.PackDetail PD WITH (NOLOCK) 
            JOIN dbo.DropID D WITH (NOLOCK) ON PD.Refno = D.DropID AND D.DropIDType = 'MASTER'
            WHERE PD.StorerKey = @c_StorerKey
            AND   PD.Refno2 = @c_GS1Label
            OPEN CUR_LOOP
            FETCH NEXT FROM CUR_LOOP INTO @c_ChildGS1Label
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               IF NOT EXISTS (SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) 
                              WHERE DropID = @c_LPNNo AND ChildID = @c_ChildGS1Label)
               BEGIN
                  INSERT INTO DROPIDDETAIL (Dropid, ChildId, AddWho, LabelPrinted)  
                  VALUES (@c_LPNNo, @c_ChildGS1Label, 'WCS', 'Y')    
                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                     SET @c_Status = '5'
                     SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
                     SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Insert DropIDDetail Table. GS1#: ' + CONVERT(VARCHAR, @c_GS1Label) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                      + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                     CLOSE CUR_LOOP
                     DEALLOCATE CUR_LOOP
                     GOTO QUIT_SP
                  END
               END
               
               FETCH NEXT FROM CUR_LOOP INTO @c_ChildGS1Label
            END
            CLOSE CUR_LOOP
            DEALLOCATE CUR_LOOP
            END
         END

         -- (ChewKP04)
         /***************************************************/
         /* Update PackInfo.Weight                          */
         /***************************************************/

         SET @f_Weight = CAST(@c_Weight AS REAL)
         IF @f_Weight > 0
         BEGIN
            UPDATE dbo.PackInfo WITH (ROWLOCK)
               SET Weight = @f_Weight
            WHERE PickSlipNo = @c_PickSlipNo
            AND   CartonNo   = @n_CartonNo

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @c_Status = '5'
               SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
               SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update PackDetail Table. GS1#: ' + CONVERT(VARCHAR, @c_GS1Label) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               GOTO QUIT_SP
            END

            EXEC dbo.nspGetRight
                @c_Facility,
                @c_StorerKey,
                NULL,
                'AgileProcess',
                @b_Success        OUTPUT,
                @c_AgileProcess   OUTPUT,
                @n_Err            OUTPUT,
                @c_ErrMsg         OUTPUT

            IF @c_AgileProcess = '1'
            BEGIN
              -- Send rate from Agile (carrier consolidation system)
               EXEC dbo.isp1156P_Agile_Rate
                   @c_PickSlipNo
                  ,@n_CartonNo
                  ,@c_GS1Label
                  ,@b_Success OUTPUT
                  ,@n_Err     OUTPUT
                  ,@c_ErrMsg  OUTPUT
               IF @n_Err <> 0 OR @b_Success <> 1
               BEGIN
                  SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12005
                  SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': isp1156P_Agile_Rate Failed. GS1#: ' + CONVERT(VARCHAR, @c_GS1Label) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
               END
            END
            
            
            /*--------------------------------------------------------------------------------------------------  
                                         Update weight, cube, carton  -- (Start) (ChewKP06)
             --------------------------------------------------------------------------------------------------*/  
           
           
           
            -- Loop LabelNo  
            DECLARE CUR_ModifyOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT DISTINCT PD.OrderKey FROM dbo.PickDetail PD WITH (NOLOCK)
               INNER JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = PD.OrderKey 
               INNER JOIN PickHeader PH WITH (NOLOCK) ON PH.ConsoOrderKey = OD.ConsoOrderKey 
               INNER JOIN PackHeader PACKH WITH (NOLOCK) ON PACKH.ConsoOrderKey = PH.ConsoOrderKey 
               INNER JOIN PackDetail PACKD WITH (NOLOCK) ON PACKD.PickSlipNo = PackH.PickSlipNo
               WHERE PackD.LabelNo = @c_GS1Label
         
            OPEN CUR_ModifyOrders  
            FETCH NEXT FROM CUR_ModifyOrders INTO @cOrderKey
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               
               
               
               SET @nTotWeight  = 0  
               SET @nTotCube    = 0
               SET @nTotCartons = 0 
         
               SET @cMBOLKey = ''
               SET @cLoadKey = ''           
               SELECT
                  --@cStorerKey = ISNULL(O.StorerKey,''),                
                  @cLoadKey = O.LoadKey,   
                  @cMBOLKey = O.MBOLKey  
               FROM Orders O WITH (NOLOCK)
               WHERE O.OrderKey = @cOrderKey   
               
               
                          
               DECLARE CUR_Carton CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT CaseID
               FROM PICKDETAIL p WITH (NOLOCK)
               WHERE p.OrderKey = @cOrderKey
         
               OPEN  CUR_Carton
               
               FETCH NEXT FROM CUR_Carton INTO @c_GS1Label 
               
               WHILE @@FETCH_STATUS <> -1
               BEGIN
               	SELECT TOP 1
               	      @cPickSlipNo = pd.PickSlipNo,
               	      @nCartonNo = pd.CartonNo 
               	FROM PackDetail pd WITH (NOLOCK)
               	WHERE pd.LabelNo = @c_GS1Label
         
                  SET @nWeight = 0 
                  SET @cCartonType = ''         	
                  SELECT @cCartonType = CartonType,
                         @nWeight = [Weight]   
                  FROM PackInfo WITH (NOLOCK)   
                  WHERE PickSlipNo = @cPickSlipNo  
                    AND CartonNo = @nCartonNo  
         
                  -- Get carton weight 
                  IF @nWeight = 0 
                  BEGIN
                     SELECT @nWeight = ISNULL( SUM( PD.QTY * SKU.StdGrossWgt), 0)  
                     FROM PackDetail PD (NOLOCK)   
                     INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)  
                     WHERE PD.LabelNo = @c_GS1Label           	
                  END 
         
                  -- Get carton cube  
                  SET @nCube = 0           
                  SELECT @nCube = ISNULL(C.Cube,0)  
                  FROM dbo.Cartonization C WITH (NOLOCK)  
                  INNER JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)  
                  WHERE C.CartonType = @cCartonType  
                     AND S.StorerKey = @c_StorerKey  
         
                  SET @nTotWeight  = @nTotWeight + @nWeight  
                  SET @nTotCube    = @nTotCube   + @nCube 
                  SET @nTotCartons = @nTotCartons + 1
         
                  -- Update CartonShipmentDetail
         --         UPDATE CartonShipmentDetail SET
         --            OrderKey = @cOrderKey, 
         --            Loadkey  = @cLoadKey, 
         --           MBOLKey  = @cMBOLKey
         --         WHERE UCCLabelNo = @c_GS1Label
         --            AND StorerKey = @cStorerKey
         --         IF @@ERROR <> 0  
         --         BEGIN  
         --            SET @nContinue = 3  
         --            SET @cErrMsg = 'Update CartonShipmentDetail Failed'  
         --            GOTO QUIT_WITH_ERROR  
         --         END  
                        	
                  FETCH NEXT FROM CUR_Carton INTO @c_GS1Label
               END  -- While        
               CLOSE CUR_Carton
               DEALLOCATE CUR_Carton
         
               UPDATE LoadPlanDetail SET  
                  Weight = @nTotWeight,   
                  Cube = @nTotCube, 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL   
               WHERE LoadKey = @cLoadKey  
                 AND OrderKey = @cOrderKey  
                 
                 
               IF @@ERROR <> 0  
               BEGIN  
                           SET @n_Continue = 3
                           SET @c_Status = '5'
         
                           SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
                           SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update LoadPlanDetail Table. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                            + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                           GOTO QUIT_SP
               END  
               
               
               IF ISNULL(@cMBOLKEY,'')  <> ''
               BEGIN
                  UPDATE MBOLDetail SET  
                  Weight = @nTotWeight,   
                  Cube = @nTotCube, 
                  EditDate = GETDATE(), 
                  TrafficCop = NULL   
               WHERE LoadKey = @cLoadKey  
                 AND OrderKey = @cOrderKey  
                 
                  IF @@ERROR <> 0  
                  BEGIN  
                              SET @n_Continue = 3
                              SET @c_Status = '5'
            
                              SELECT @c_ErrMsg = CONVERT(Char(250),@n_Err), @n_Err = 12004
                              SELECT @c_ErrMsg = 'NSQL'+CONVERT(Char(5),@n_Err)+': Error Update MBOLDetail Table. Pallet#: ' + CONVERT(VARCHAR, @c_LPNNo) + '. (isp_TCP_CLOSE_PALLET_IN)'
                                               + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg),'') + ' ) '
                              GOTO QUIT_SP
                  END                   
               END
               
         
               -- Add to new MBOLDetail
               -- Conso order with 1 carton split into multi orders. Can't calculate carton count, weight, cube. Stamp as 1
               
         --      UPDATE MBOLDetail SET  
         --         Weight = CASE WHEN @nTotWeight = 0 THEN 1 ELSE @nTotWeight END,  
         --         Cube   = CASE WHEN @nTotCube = 0 THEN 1 ELSE @nTotCube END,  
         --         TotalCartons = @nTotCartons,  
         --         EditDate = GETDATE(), 
         --         TrafficCop = NULL 
         --      WHERE MBOLKey = @cMBOLKey  
         --         AND OrderKey = @cOrderKey  
         --      IF @@ERROR <> 0  
         --      BEGIN  
         --         SET @nContinue = 3  
         --         SET @cErrMsg = 'Update MBOLDetail Failed'  
         --         GOTO QUIT_WITH_ERROR  
         --      END  
               FETCH NEXT FROM CUR_ModifyOrders INTO @cOrderKey
            END  -- While CUR_ModifyOrders
            CLOSE CUR_ModifyOrders  
            DEALLOCATE CUR_ModifyOrders  
            
            /*--------------------------------------------------------------------------------------------------  
                                         Update weight, cube, carton  -- (End) (ChewKP06)
             --------------------------------------------------------------------------------------------------*/  
         END

         /***************************************************/
         /* Interface with AGILE                            */
         /***************************************************/


          IF @b_Debug = 1
          BEGIN
               SELECT '@c_CartonLine : '       + @c_CartonLine
                    + ', @c_GS1Label : '       + @c_GS1Label
                    + ', @c_Weight : '         + @c_Weight
                    + ', @c_PickSlipNo : '     + @c_PickSlipNo
                    + ', @n_CartonNo : '       + CAST(@n_CartonNo AS CHAR(5))
          END
    END

    FETCH NEXT FROM CUR_LINE INTO @n_SeqNo, @c_LineText
   END
   CLOSE CUR_LINE
   DEALLOCATE CUR_LINE


   IF @b_Debug = 1
   BEGIN
      SELECT '@c_MessageType : '       + @c_MessageType
           + ', @c_MessageNumber : '   + @c_MessageNumber
           + ', @c_StorerKey : '       + @c_StorerKey
           + ', @c_Facility : '        + @c_Facility
           + ', @c_LPNNo : '           + @c_LPNNo
           + ', @c_LaneNumber : '      + @c_LaneNumber

   END

   QUIT_SP:

   IF @b_Debug = 1
   BEGIN
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status
           + ', @c_ErrMsg : ' + @c_ErrMsg
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      ROLLBACK TRAN WCS_BULK_PICK
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_CLOSE_PALLET_IN'
   END

   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)
   SET STATUS   = @c_Status
     , ErrMsg   = @c_ErrMsg
     , Editdate = GETDATE()
     , EditWho  = SUSER_SNAME()
   WHERE SerialNo = @n_SerialNo

   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started
      COMMIT TRAN WCS_BULK_PICK

   RETURN
END

GO