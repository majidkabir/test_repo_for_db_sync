SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_857ExtUpdSP04                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Call From rdtfnc_Driver_CheckIn                             */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-06-25  1.0  PYU015   Created                                    */
/************************************************************************/

CREATE   PROC [RDT].[rdt_857ExtUpdSP04] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR(3),
   @nStep          INT,
   @cStorerKey     NVARCHAR(15),
   @cContainerNo   NVARCHAR(20),
   @cAppointmentNo NVARCHAR(20),
   @nInputKey      INT,
   @cActionType    NVARCHAR( 10) ,
   @cInField04     NVARCHAR( 20) ,
   @cInField06     NVARCHAR( 20) ,
   @cInField08     NVARCHAR( 20) ,
   @cInField10     NVARCHAR( 20) ,
   @cOutField01    NVARCHAR( 20) OUTPUT,
   @cOutField02    NVARCHAR( 20) OUTPUT,
   @cOutField03    NVARCHAR( 20) OUTPUT,
   @cOutField04    NVARCHAR( 20) OUTPUT,
   @cOutField05    NVARCHAR( 20) OUTPUT,
   @cOutField06    NVARCHAR( 20) OUTPUT,
   @cOutField07    NVARCHAR( 20) OUTPUT,
   @cOutField08    NVARCHAR( 20) OUTPUT,
   @cOutField09    NVARCHAR( 20) OUTPUT,
   @cOutField10    NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nTranCount     INT
,@nCount                INT
,@cFieldDescr           NVARCHAR(20)
,@cValue                NVARCHAR(20)
,@cLong                 NVARCHAR(30)
,@cExecStatements       NVARCHAR(4000)
,@cUserName             NVARCHAR( 18)
,@cFacility             NVARCHAR( 5)
,@cWeight               FLOAT
,@cContainerKey         NVARCHAR(10)
,@cContainerLineNumber  NVARCHAR( 5)
,@cOrderType            NVARCHAR(30)
,@cPalletKey            NVARCHAR(10)
,@cEmptyPalletWgt       FLOAT
,@cEmptyTruckWgt        FLOAT
,@cFullTruckWgt         FLOAT
,@cRemainWgt            FLOAT
,@cGrossPalletWgt       FLOAT
,@cNetPalletWgt         FLOAT
,@cPalletCnt            INT
,@c_cnt                 INT
,@clottable07           NVARCHAR(30)
,@clottable10           NVARCHAR(30)
,@cBagWgt               FLOAT
,@cUDF01                NVARCHAR(60)

SET @nErrNo   = 0
SET @cErrMsg  = ''
SET @nTranCount = @@TRANCOUNT
SET @nCount = 1
SET @cOutField01 = ''
SET @cOutField02 = ''
SET @cOutField03 = ''
SET @cOutField04 = ''
SET @cOutField05 = ''
SET @cOutField06 = ''
SET @cOutField07 = ''
SET @cOutField08 = ''
SET @cOutField09 = ''
SET @cOutField10 = ''



   IF @nFunc = 857
   BEGIN
      SELECT @cFacility = Facility
            ,@cUserName = UserName
        FROM rdt.rdtMobrec WITH (NOLOCK)
       WHERE Mobile = @nMobile

      IF @nStep = 1  -- Display Information
      BEGIN
        IF @nInputKey = 1
        BEGIN
          IF @cActionType = '12'
          BEGIN
            IF EXISTS (SELECT 1 FROM dbo.IDS_VEHICLE v WITH (NOLOCK) WHERE VehicleNumber = @cContainerNo and Weight > 0)
            BEGIN
            SET @nErrNo = 218701
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'^ContainerExist'
            GOTO RollBackTran
            END

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Description , Long
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'RDTWAT'
            AND StorerKey = @cStorerKey
            AND UDF01 = 'D'
            AND UDF02 = '12'
            Order By Code

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

           WHILE @@FETCH_STATUS <> -1
           BEGIN
                 SET @cValue = ''
            
                IF @nCount = 1
                 BEGIN
                 SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                 SET @cOutField04 = @cValue
                 END
                 ELSE IF @nCount = 2
                 BEGIN
                 SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                 SET @cOutField06 = @cValue
                 END
                 ELSE IF @nCount = 3
                 BEGIN
                 SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                 SET @cOutField08 = @cValue
                 END
                 ELSE IF @nCount = 4
                 BEGIN
                 SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                 SET @cOutField10 = @cValue
                 END

                 SET @nCount = @nCount + 1
                 FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
           END
           CLOSE CursorCodeLkup
           DEALLOCATE CursorCodeLkup

           IF ISNULL(@cContainerNo,'')  <>  ''
              BEGIN
              SET @cOutField01 = 'ContainerNo: '
              SET @cOutField02 = @cContainerNo
              END
              ELSE
              BEGIN
              SET @cOutField01 = 'AppointmentNo: '
              SET @cOutField02 = @cAppointmentNo
              END
           END
          
         IF @cActionType = '22'
         BEGIN
            SELECT @cWeight = ISNULL(Weight,0)
            FROM dbo.IDS_VEHICLE v WITH (NOLOCK)
            WHERE v.VehicleNumber = @cContainerNo
            IF @@ROWCOUNT = 0
            BEGIN
            SET @nErrNo = 218702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'^No Container'
            GOTO RollBackTran
            END

            IF @cWeight = 0
            BEGIN
            SET @nErrNo = 218703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'^Need Weight
            GOTO RollBackTran
            END

            IF NOT EXISTS (SELECT 1 FROM dbo.CONTAINER ctn WITH (NOLOCK)
            WHERE ctn.CarrierKey = @cContainerNo
            and ctn.Status < '9')
            BEGIN
            SET @nErrNo = 218704
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'^No Mbol'
            GOTO RollBackTran
            END

            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

                SELECT Description , Long
                FROM dbo.CodeLkup WITH (NOLOCK)
                WHERE ListName = 'RDTWAT'
                AND StorerKey = @cStorerKey
                AND UDF01 = 'D'
                AND UDF02 = '22'
                Order By Code

                OPEN CursorCodeLkup
                FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

                WHILE @@FETCH_STATUS <> -1
                BEGIN
                   SET @cValue = ''

                   SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +  
                                             ' FROM  dbo.CONTAINER WITH(NOLOCK) ' +
                                             ' INNER JOIN dbo.IDS_VEHICLE WITH (NOLOCK) on CONTAINER.CarrierKey = IDS_VEHICLE.VehicleNumber' + 
                                             ' WHERE IDS_VEHICLE.VehicleNumber = @cContainerNo'  +
                                             ' AND   CONTAINER.status < ''9'''
  
  
                   EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cContainerNo NVARCHAR(20)  '  
                                                     , @cValue OUTPUT, @cContainerNo

                   IF @nCount = 1
                   BEGIN
                   SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                   SET @cOutField04 = @cValue
                   END
                   ELSE IF @nCount = 2
                   BEGIN
                   SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                   SET @cOutField06 = @cValue
                   END
                   ELSE IF @nCount = 3
                   BEGIN
                   SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                   SET @cOutField08 = @cValue
                   END
                   ELSE IF @nCount = 4
                   BEGIN
                   SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                   SET @cOutField10 = @cValue
                   END

                   SET @nCount = @nCount + 1
                   FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
               END
               CLOSE CursorCodeLkup
               DEALLOCATE CursorCodeLkup

               IF ISNULL(@cContainerNo,'')  <>  ''
               BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
               END
               ELSE
               BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
               END
         END
       END
     END

     IF @nStep = 2  -- Get Input Information
     BEGIN
        IF @nInputKey = 1  
        BEGIN
          IF @cActionType = '12'
         BEGIN
         
            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

               SELECT Description, Long
               FROM dbo.CodeLkup WITH (NOLOCK)
               WHERE ListName = 'RDTWAT'
               AND StorerKey = @cStorerKey
               AND UDF01 = 'I'
               AND UDF02 = '12'
               Order By Code

               OPEN CursorCodeLkup
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @cValue = ''

                  IF @nCount = 1
                  BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
                  END
                  ELSE IF @nCount = 2
                  BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = @cValue
                  END
                  ELSE IF @nCount = 3
                  BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
                  END
                  ELSE IF @nCount = 4
                  BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField10 = @cValue
                  END

                  SET @nCount = @nCount + 1
                  FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
               END
               CLOSE CursorCodeLkup
               DEALLOCATE CursorCodeLkup

               IF ISNULL(@cContainerNo,'')  <>  ''
               BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
               END
               ELSE
               BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
               END
         END
       
          IF @cActionType = '22'
          BEGIN
            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

               SELECT Description, Long
               FROM dbo.CodeLkup WITH (NOLOCK)
               WHERE ListName = 'RDTWAT'
               AND StorerKey = @cStorerKey
               AND UDF01 = 'I'
               AND UDF02 = '22'
               Order By Code

               OPEN CursorCodeLkup
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SET @cValue = ''

                  IF @nCount = 1
                  BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
                  END
                  ELSE IF @nCount = 2
                  BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = @cValue
                  END
                  ELSE IF @nCount = 3
                  BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
                  END
                  ELSE IF @nCount = 4
                  BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField10 = @cValue
                  END

                  SET @nCount = @nCount + 1
                  FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
               END
               CLOSE CursorCodeLkup
               DEALLOCATE CursorCodeLkup

               IF ISNULL(@cContainerNo,'')  <>  ''
               BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
               END
               ELSE
               BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
               END
         END
       END
     END

     IF @nStep = 3
     BEGIN
        IF @nInputKey = 1 
        BEGIN
          IF @cActionType = '12'
         BEGIN

               BEGIN TRAN
               SAVE TRAN CheckIn85704

               IF EXISTS(SELECT 1 FROM IDS_VEHICLE WITH(NOLOCK) WHERE VehicleNumber = @cContainerNo)
               BEGIN
               UPDATE IDS_VEHICLE WITH(ROWLOCK)
               SET Weight = @cInField04
               WHERE VehicleNumber = @cContainerNo
               END
               ELSE
               BEGIN
               INSERT INTO dbo.IDS_VEHICLE(VehicleNumber,Weight) VALUES(@cContainerNo,@cInField04)
               END

              IF @@ERROR <> 0
              BEGIN
              SET @nErrNo = 218705
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsContainerFail'
              GOTO RollBackTran
              END

              EXEC RDT.rdt_STD_EventLog
                  @cActionType   = @cActionType, -- '12', -- Check IN
                  @cUserID       = @cUserName,
                  @nMobileNo     = @nMobile,
                  @nFunctionID   = @nFunc,
                  @cFacility     = @cFacility,
                  @cStorerKey    = @cStorerKey,
                  @cContainerNo  = @cContainerNo,
                  @cRefNo4       = ''

               COMMIT TRAN CheckIn85704

         END

         IF @cActionType = '22'
         BEGIN

            SELECT @cEmptyTruckWgt = ISNULL(Weight,0)
              FROM dbo.IDS_VEHICLE v WITH (NOLOCK)
             WHERE v.VehicleNumber = @cContainerNo

            SELECT @cFullTruckWgt = @cInField04


            SELECT @cPalletCnt = COUNT(1)
              FROM CONTAINER ctn WITH(NOLOCK)
             INNER JOIN CONTAINERDETAIL dtl WITH(NOLOCK) ON ctn.ContainerKey = dtl.ContainerKey
             INNER JOIN ORDERS o with(nolock) on dtl.Userdefine04 = o.OrderKey
             WHERE ctn.CarrierKey = @cContainerNo
               AND o.Status < '9'


            IF @cFullTruckWgt <= @cEmptyTruckWgt
            BEGIN
               SET @nErrNo = 00000
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad Weight'  
               GOTO RollBackTran  
            END

            SET @c_cnt = 0
            SET @cContainerLineNumber = SPACE(5)
            SET @cRemainWgt = @cFullTruckWgt - @cEmptyTruckWgt

            BEGIN TRAN
            SAVE TRAN CheckIn85704
            WHILE(1=1)
            BEGIN
                 SELECT TOP 1
                        @cContainerLineNumber = dtl.ContainerLineNumber,
                        @cContainerKey = ctn.ContainerKey,
                        @cOrderType = o.Type,
                        @cPalletKey = dtl.PalletKey,
                        @cWeight = dtl.Userdefine01,
                        @cUDF01 = lk.UDF01
                   FROM CONTAINER ctn WITH(NOLOCK)
                  INNER JOIN CONTAINERDETAIL dtl WITH(NOLOCK) ON ctn.ContainerKey = dtl.ContainerKey
                  INNER JOIN ORDERS o WITH(NOLOCK) ON dtl.Userdefine04 = o.OrderKey
                  INNER JOIN codelkup lk WITH(NOLOCK) ON o.Type = lk.Code AND lk.LISTNAME = 'ORDERTYPE' AND lk.Storerkey = o.StorerKey
                  WHERE ctn.CarrierKey = @cContainerNo
                    AND o.Status < '9'
                    AND dtl.ContainerLineNumber > @cContainerLineNumber
                  ORDER BY ctn.CarrierKey,dtl.ContainerLineNumber

                  IF @@ROWCOUNT = 0 
                  BEGIN
                     BREAK
                  END

                  SELECT TOP 1 @clottable07 = ATTR.lottable07,
                               @cBagWgt     = INV.qty * CASE WHEN ISNULL(ATTR.Lottable10,'0') in ('','0') THEN S.TareWeight ELSE ATTR.Lottable10 END
                    FROM LOTxLOCxID INV WITH(NOLOCK)
                   INNER JOIN LOTATTRIBUTE ATTR WITH(NOLOCK) ON INV.lot = ATTR.lot AND INV.sku = ATTR.sku AND INV.storerkey = ATTR.storerkey
                   INNER JOIN SKU S WITH(NOLOCK) ON INV.StorerKey = S.StorerKey AND INV.Sku = S.Sku
                   WHERE INV.id = @cPalletKey
                     AND INV.storerkey = @cStorerKey
                     AND INV.qty > 0



                  IF @cUDF01 = 'LOOSELOADING'   -- Loose Load
                  BEGIN
                     IF ISNULL(@cWeight,'') IN ('','0')
                     BEGIN
                        SET @nErrNo = 218707  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'NeedEmptyPLWgt'  
                        GOTO RollBackTran  
                     END
                     ELSE
                     BEGIN
                     SELECT @cEmptyPalletWgt = @cWeight
                     END
                  END
                  ELSE
                  BEGIN
                     SELECT @cEmptyPalletWgt = @clottable07
                  END


                  IF @cPalletCnt =  @c_cnt + 1
                  BEGIN
                    SELECT @cGrossPalletWgt = @cRemainWgt
                  END
                  ELSE
                  BEGIN
                    SELECT @cGrossPalletWgt = FLOOR((@cFullTruckWgt - @cEmptyTruckWgt) / @cPalletCnt )
                    SELECT @cRemainWgt = @cRemainWgt - @cGrossPalletWgt
                  END
                  
                  IF @cUDF01 = 'LOOSELOADING'  -- Loose Load
                  BEGIN
                    SELECT @cNetPalletWgt = @cGrossPalletWgt - @cBagWgt
                  END
                  ELSE 
                  BEGIN
                    SELECT @cNetPalletWgt = @cGrossPalletWgt - @cBagWgt - @cEmptyPalletWgt
                  END

                  
                  UPDATE dbo.CONTAINERDETAIL WITH(ROWLOCK)
                     SET Userdefine02 = @cGrossPalletWgt
                        ,Userdefine03 = @cNetPalletWgt
                   WHERE ContainerKey = @cContainerKey
                     AND  ContainerLineNumber = @cContainerLineNumber

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 218708  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdMbolDetailFail'  
                     GOTO RollBackTran  
                  END  

                  SELECT @c_cnt += 1
            END

            DELETE 
            FROM IDS_VEHICLE 
            WHERE VehicleNumber = @cContainerNo
         
            IF @@ERROR <> 0  
            BEGIN
            SET @nErrNo = 218709
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Failed To Dele'  
            GOTO RollBackTran  
            END

            EXEC RDT.rdt_STD_EventLog
                @cActionType   = @cActionType, -- '12', -- Check IN
                @cUserID       = @cUserName,
                @nMobileNo     = @nMobile,
                @nFunctionID   = @nFunc,
                @cFacility     = @cFacility,
                @cStorerKey    = @cStorerKey,
                @cContainerNo  = @cContainerNo, 
                @cRefNo4       = ''            
           
            COMMIT TRAN CheckIn85704
         END
        END

       IF @nInputKey = 0
       BEGIN
          IF @cActionType = '12'
          BEGIN
            DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

            SELECT Description, Long
               FROM dbo.CodeLkup WITH (NOLOCK)
               WHERE ListName = 'RDTWAT'
               AND StorerKey = @cStorerKey
               AND UDF01 = 'D'
               AND UDF02 = '12'
               Order By Code

            OPEN CursorCodeLkup
            FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

            WHILE @@FETCH_STATUS <> -1
               BEGIN
                  SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +
                                            ' FROM dbo.IDS_VEHICLE v WITH (NOLOCK) ' +
                                            ' WHERE v.VehicleNumber = @cContainerNo'


                  EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cContainerNo NVARCHAR(20) '
                                                     , @cValue OUTPUT, @cContainerNo

                  IF @nCount = 1
                  BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
                  END
                  ELSE IF @nCount = 2
                  BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = @cValue
                  END
                  ELSE IF @nCount = 3
                  BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
                  END
                  ELSE IF @nCount = 4
                  BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField10 = @cValue
                  END

                  SET @nCount = @nCount + 1
                  FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
               END
               CLOSE CursorCodeLkup
               DEALLOCATE CursorCodeLkup

               IF ISNULL(@cContainerNo,'')  <>  ''
               BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
               END
               ELSE
               BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
               END
            END
       
          IF @cActionType = '22'
          BEGIN
               DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

               SELECT Description, Long
               FROM dbo.CodeLkup WITH (NOLOCK)
               WHERE ListName = 'RDTWAT'
               AND StorerKey = @cStorerKey
               AND UDF01 = 'D'
               AND UDF02 = '22'
               Order By Code

               OPEN CursorCodeLkup
               FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong

               WHILE @@FETCH_STATUS <> -1
               BEGIN
                   SELECT @cExecStatements = 'SELECT @cValue = ' + @cLong +  
                                             ' FROM  dbo.CONTAINER WITH(NOLOCK) ' +
                                             ' INNER JOIN dbo.IDS_VEHICLE WITH (NOLOCK) on CONTAINER.CarrierKey = IDS_VEHICLE.VehicleNumber' + 
                                             ' WHERE IDS_VEHICLE.VehicleNumber = @cContainerNo'  +
                                             ' AND   CONTAINER.status < ''9'''
  
  
                  EXEC sp_executesql @cExecStatements, N'@cValue NVARCHAR(20) OUTPUT, @cContainerNo NVARCHAR(20)  '  
                                                     , @cValue OUTPUT, @cContainerNo

                  IF @nCount = 1
                  BEGIN
                  SET @cOutField03 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField04 = @cValue
                  END
                  ELSE IF @nCount = 2
                  BEGIN
                  SET @cOutField05 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField06 = @cValue
                  END
                  ELSE IF @nCount = 3
                  BEGIN
                  SET @cOutField07 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField08 = @cValue
                  END
                  ELSE IF @nCount = 4
                  BEGIN
                  SET @cOutField09 = ISNULL(RTRIM(@cFieldDescr),'' ) + ':'
                  SET @cOutField10 = @cValue
                  END

                  SET @nCount = @nCount + 1
                  FETCH NEXT FROM CursorCodeLkup INTO @cFieldDescr, @cLong
               END
               CLOSE CursorCodeLkup
               DEALLOCATE CursorCodeLkup

               IF ISNULL(@cContainerNo,'')  <>  ''
               BEGIN
               SET @cOutField01 = 'ContainerNo: '
               SET @cOutField02 = @cContainerNo
               END
               ELSE
               BEGIN
               SET @cOutField01 = 'AppointmentNo: '
               SET @cOutField02 = @cAppointmentNo
               END            
         END
       END
     END
   END
   
   
   GOTO QUIT

   RollBackTran:
   IF @@TRANCOUNT>@nTranCount
   ROLLBACK TRAN CheckIn85704

   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
   COMMIT TRAN CheckIn85704

Fail:
END


GO