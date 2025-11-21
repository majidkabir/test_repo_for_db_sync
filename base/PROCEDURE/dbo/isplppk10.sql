SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispLPPK10                                          */
/* Creation Date: 12-APR-2022                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19420 CN Licombined load plan generate packing          */
/*                                                                      */
/* Called By: Load Plan                                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 12-APR-2022  NJOW     1.0  DEVOPS Combine script                     */
/************************************************************************/

CREATE PROC [dbo].[ispLPPK10]
   @cLoadKey    NVARCHAR(10),
   @bSuccess    INT      OUTPUT,
   @nErr        INT      OUTPUT,
   @cErrMsg     NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipno NVARCHAR(10),
           @cOrderKey   NVARCHAR(10),
           @cStorerKey  NVARCHAR(15),
           @cSKU        NVARCHAR(20),
           @nQty        INT,
           @nContinue   INT,
           @nStartTCnt  INT,
           @cCartonGroup NVARCHAR(10),
           @cLabelNo NVARCHAR(20),
           @cDiscreteOrConso NCHAR(1),
           @cBatch_PickSlipno NVARCHAR(10),
           @nBatch_PickSlipno INT,
           @nPS_count   INT,
           @cBatch_LabelNo NVARCHAR(20),
           @nBatch_LabelNo BIGINT,
           @nLabelNo_count INT

   DECLARE @cGenUCCLabelNoConfig NVARCHAR(10),
           @cIdentifier    NVARCHAR(2),
	         @cPacktype      NVARCHAR(1),
           @cVAT           NVARCHAR(18),
           @cPackNo_Long   NVARCHAR(250),
           @cKeyname       NVARCHAR(30),
           @nCheckDigit    INT,
           @nTotalCnt      INT,
           @nTotalOddCnt   INT,
           @nTotalEvenCnt  INT,
           @nAdd           INT,
           @nDivide        INT,
           @nRemain        INT,
           @nOddCnt        INT,
           @nEvenCnt       INT,
           @nOdd           INT,
           @nEven          INT

	SELECT @nContinue=1, @nStartTCnt=@@TRANCOUNT, @nErr = 0, @cErrMsg = ''
	SELECT @cDiscreteOrConso = 'D', @cPickSlipno = '', @cLabelNo = ''

   IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK)
             JOIN  ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey
             WHERE PD.Status='4' AND PD.Qty > 0
              AND  O.LoadKey = @cLoadKey)
   BEGIN
	    SELECT @nContinue=3
	    SELECT @nErr = 38002
	    SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': Found Short Pick with Qty > 0 '
      GOTO QUIT_SP
   END

   SELECT @cPickSlipno = Pickheaderkey
   FROM PICKHEADER (NOLOCK)
   WHERE ExternOrderkey = @cLoadKey
   AND ISNULL(Orderkey,'')=''

   IF ISNULL(@cPickSlipno,'') <> ''
   BEGIN
   	  SELECT @cDiscreteOrConso = 'C'

   	  SELECT TOP 1 @cLabelNo = LabelNo
   	  FROM PACKDETAIL (NOLOCK)
   	  WHERE Pickslipno = @cPickSlipno

   	  IF ISNULL(@cLabelNo,'') <> ''
   	  BEGIN
   	  	 SELECT @nContinue=3
	       SELECT @nErr = 38003
	       SELECT @cErrmsg='NSQL'+CONVERT(varchar(5),@nErr)+': This Load Plan Already Started Consolidated Packing at Pick Slip# ' + ISNULL(@cPickSlipno,'')
         GOTO QUIT_SP
      END
   END

   SELECT TOP 1 @cStorerkey = Storerkey
   FROM ORDERS(NOLOCK)
   WHERE Loadkey = @cLoadKey

   EXEC nspGetRight
     @c_Facility  = NULL,
     @c_StorerKey = @cStorerKey,
     @c_sku       = NULL,
     @c_ConfigKey = 'GenUCCLabelNoConfig',
     @b_Success   = @bSuccess               OUTPUT,
     @c_authority = @cGenUCCLabelNoConfig   OUTPUT,
     @n_err       = @nErr                   OUTPUT,
     @c_errmsg    = @cErrMsg                OUTPUT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @cDiscreteOrConso = 'D'
   BEGIN
      SELECT @nPS_count = 0

      SELECT @nPS_count = Count(1)
      FROM   LoadplanDetail (NOLOCK)
      WHERE  LoadplanDetail.loadkey = @cLoadKey
      AND NOT Exists ( SELECT 1
         FROM PickHeader PH (NOLOCK)
         WHERE PH.OrderKey = LoadplanDetail.Orderkey )

      IF @nPS_count is null
         SET @nPS_count = 0

      IF @nPS_count > 0
      BEGIN
         BEGIN TRAN
         EXECUTE nspg_GetKey
 			      'PICKSLIP',
 			      9,
 			      @cBatch_PickSlipno	OUTPUT,
 			      @bSuccess				OUTPUT,
 			      @nErr					OUTPUT,
 			      @cErrmsg				OUTPUT,
            0,
            @nPS_count
         IF NOT @bSuccess = 1
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38014
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey (ispLPPK10)'
            GOTO QUIT_SP
         END
         ELSE
         BEGIN
            COMMIT TRAN
         END
         SET @nBatch_PickSlipno = CAST(@cBatch_PickSlipno as INT)
      END

      SELECT @nLabelNo_count = 0

      SELECT @nLabelNo_count = Count(DISTINCT PD.Orderkey)
      FROM   LoadplanDetail (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = LoadplanDetail.Orderkey
      WHERE  LoadplanDetail.loadkey = @cLoadKey
      AND NOT Exists ( SELECT 1
                     FROM PackHeader PH (NOLOCK)
                     JOIN PackDetail PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
                     WHERE PH.OrderKey = LoadplanDetail.Orderkey )

      IF @nLabelNo_count is null
         SET @nLabelNo_count = 0
   END
   ELSE
   BEGIN --CONSO
      SELECT @nLabelNo_count = 1
   END

   IF @nLabelNo_count > 0
   BEGIN
      BEGIN TRAN

      IF @cGenUCCLabelNoConfig = '1'
      BEGIN
         SET @cIdentifier = '00'
  	     SET @cPacktype = '0'

         SELECT @cVAT = ISNULL(Vat,'')
	       FROM Storer WITH (NOLOCK)
	       WHERE Storerkey = @cStorerkey

         IF ISNULL(@cVAT,'') = ''
	          SET @cVAT = '000000000'

	       IF LEN(@cVAT) <> 9
            SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)

	       SELECT @cPackNo_Long = Long
         FROM  CODELKUP (NOLOCK)
         WHERE ListName = 'PACKNO'
         AND Code = @cStorerkey

         IF ISNULL(@cPackNo_Long,'') = ''
         	  SET @cKeyname = 'TBLPackNo'
         ELSE
            SET @cKeyname = 'PackNo' + LTRIM(RTRIM(ISNULL(@cPackNo_Long,'')))

         EXECUTE nspg_GetKey
 		         @ckeyname,
 		         7,
 		         @cBatch_LabelNo	OUTPUT,
 		         @bSuccess			OUTPUT,
 		         @nErr					OUTPUT,
 		         @cErrmsg				OUTPUT,
             0,
             @nLabelNo_count
  	  END
  	  ELSE
  	  BEGIN
         EXECUTE nspg_GetKey
 		         'PACKNO',
 		         10,
 		         @cBatch_LabelNo	OUTPUT,
 		         @bSuccess			OUTPUT,
 		         @nErr					OUTPUT,
 		         @cErrmsg				OUTPUT,
             0,
             @nLabelNo_count
      END

      IF NOT @bSuccess = 1
      BEGIN
         SELECT @nContinue = 3
         SELECT @nErr = 38015
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Getkey PACKNO (ispLPPK10)'
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         COMMIT TRAN
      END
      SET @nBatch_LabelNo = CAST(@cBatch_LabelNo as BIGINT)
   END

   BEGIN TRAN

   DECLARE CUR_ORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey
   FROM   LoadplanDetail (NOLOCK)
   WHERE  loadkey = @cLoadKey

   OPEN CUR_ORDER

   FETCH NEXT FROM CUR_ORDER INTO @cOrderKey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	  IF @cDiscreteOrConso = 'D'
   	  BEGIN
         SET @cPickSlipno = ''
         SELECT @cPickSlipno = PickheaderKey
         FROM PickHeader (NOLOCK)
         WHERE OrderKey = @cOrderKey

         -- Create Pickheader
         IF ISNULL(@cPickSlipno ,'') = ''
         BEGIN
            SET @cBatch_PickSlipno = RTrim(LTrim(CONVERT(NVARCHAR(9),@nBatch_PickSlipno)))
            SET @cBatch_PickSlipno = RIGHT(RTrim(Replicate('0',9) + @cBatch_PickSlipno),9)

            SELECT @cPickslipno = 'P'+@cBatch_PickSlipno

            INSERT INTO PICKHEADER
                        (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
                 VALUES (@cPickslipno , @cLoadKey, @cOrderKey, '0', '3', '')

            Set @nBatch_PickSlipno = @nBatch_PickSlipno + 1
         END

         IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @cPickslipno) = 0
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                 VALUES (@cPickslipno ,GETDATE(),sUser_sName(), NULL)
         END
      END

      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET    PickSlipNo = @cPickSlipNo
            ,TrafficCop = NULL
      WHERE  OrderKey = @cOrderKey

      -- Create packheader if not exists
      IF (SELECT COUNT(1) FROM PACKHEADER (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) = 0
      BEGIN
      	 IF @cDiscreteOrConso = 'C'
      	 BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                   SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @cPickSlipNo
                   FROM  PICKHEADER PH (NOLOCK)
                   JOIN  Orders O (NOLOCK) ON (PH.ExternOrderkey = O.Loadkey)
                   WHERE PH.PickHeaderKey = @cPickSlipNo
         END
         ELSE
         BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)
                   SELECT O.Route, O.OrderKey, SUBSTRING(O.ExternOrderKey, 1, 18), O.LoadKey, O.ConsigneeKey, O.Storerkey, @cPickSlipNo
                   FROM  PICKHEADER PH (NOLOCK)
                   JOIN  Orders O (NOLOCK) ON (PH.Orderkey = O.Orderkey)
                   WHERE PH.PickHeaderKey = @cPickSlipNo
         END
      END
      ELSE
      BEGIN
      	  IF @cDiscreteOrConso = 'C'
      	  BEGIN
             IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND refno = @cOrderkey) > 0
                GOTO SKIP_ORDER
          END
      	  ELSE
      	  BEGIN
             IF (SELECT COUNT(1) FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @cPickSlipNo) > 0
                GOTO SKIP_ORDER
          END
      END

      DECLARE CUR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT StorerKey, SKU, SUM(QTY)
         FROM   PICKDETAIL p WITH (NOLOCK)
         WHERE  p.OrderKey = @cOrderKey
         AND    P.Qty > 0
         GROUP BY StorerKey, SKU

      OPEN CUR_PICKDETAIL

      IF @cDiscreteOrConso = 'D'
      BEGIN
        SELECT @cLabelNo = ''
      END

      FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty
      WHILE @@FETCH_STATUS<>-1
      BEGIN
      	 IF ISNULL(@cLabelNo,'') = ''
         BEGIN
            IF @cGenUCCLabelNoConfig = '1'
            BEGIN
               SET @cBatch_LabelNo = RTrim(LTrim(CONVERT(NVARCHAR(7),@nBatch_LabelNo)))
               SET @cBatch_LabelNo = RIGHT(RTrim(Replicate('0',7) + @cBatch_LabelNo),7)
            	 SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(ISNULL(@cVAT,'')) + RTRIM(@cBatch_LabelNo) --+ @nCheckDigit

               SET @nOdd = 1
               SET @nOddCnt = 0
               SET @nTotalOddCnt = 0
               SET @nTotalCnt = 0

               WHILE @nOdd <= 20
               BEGIN
		             SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)
		             SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
		             SET @nOdd = @nOdd + 2
               END

	             SET @nTotalCnt = (@nTotalOddCnt * 3)

	             SET @nEven = 2
               SET @nEvenCnt = 0
               SET @nTotalEvenCnt = 0

	             WHILE @nEven <= 20
               BEGIN
		             SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)
		             SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
		             SET @nEven = @nEven + 2
	             END

               SET @nAdd = 0
               SET @nRemain = 0
               SET @nCheckDigit = 0

	             SET @nAdd = @nTotalCnt + @nTotalEvenCnt
	             SET @nRemain = @nAdd % 10
	             SET @nCheckDigit = 10 - @nRemain

	             IF @nCheckDigit = 10
			            SET @nCheckDigit = 0

	             SET @cLabelNo = ISNULL(RTRIM(@cLabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
            END
            ELSE
            BEGIN
               SET @cBatch_LabelNo = RTrim(LTrim(CONVERT(NVARCHAR(10),@nBatch_LabelNo)))
               SET @cBatch_LabelNo = RIGHT(RTrim(Replicate('0',10) + @cBatch_LabelNo),10)
               SET @cLabelNo = @cBatch_LabelNo
            END

            Set @nBatch_LabelNo = @nBatch_LabelNo + 1
         END

         -- CartonNo and LabelLineNo will be inserted by trigger
         INSERT INTO PACKDETAIL
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)
         VALUES
            (@cPickSlipNo, 0, @cLabelNo, '00000', @cStorerKey, @cSKU,
             @nQty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @cOrderKey)

         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38004
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Insert PackDetail Table (ispLPPK10)'
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_PICKDETAIL INTO @cStorerKey, @cSKU, @nQty
      END
      CLOSE CUR_PICKDETAIL
      DEALLOCATE CUR_PICKDETAIL

      SKIP_ORDER:
      
      IF @cDiscreteOrConso = 'D'
      BEGIN
      	 UPDATE PACKHEADER WITH (ROWLOCK) 
      	 SET Status = '9'
      	 WHERE Pickslipno = @cPickSlipNo
      	 AND Status <> '9'

         IF @@ERROR <> 0
         BEGIN
            SELECT @nContinue = 3
            SELECT @nErr = 38005
            SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK10)'
            GOTO QUIT_SP
         END      	 
      END

      FETCH NEXT FROM CUR_ORDER INTO @cOrderKey
   END
   CLOSE CUR_ORDER
   DEALLOCATE CUR_ORDER
   
   IF @cDiscreteOrConso = 'C'
   BEGIN
   	  UPDATE PACKHEADER WITH (ROWLOCK) 
   	  SET Status = '9'
   	  WHERE Pickslipno = @cPickslipno
   	  AND Status <> '9'

      IF @@ERROR <> 0
      BEGIN
         SELECT @nContinue = 3
         SELECT @nErr = 38006
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErr)+': Error Update PackHeader Table (ispLPPK10)'
         GOTO QUIT_SP
      END      	 
   END   

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   WHILE @@TRANCOUNT < @nStartTCnt
   BEGIN
      BEGIN TRAN
   END

   QUIT_SP:

	IF @nContinue=3  -- Error Occured - Process AND Return
	BEGIN
	   SELECT @bSuccess = 0
		IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @nStartTCnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @nStartTCnt
			BEGIN
				COMMIT TRAN
			END
		END
		EXECUTE dbo.nsp_LogError @nErr, @cErrmsg, 'ispLPPK10'
		RAISERROR (@cErrmsg, 16, 1) WITH SETERROR    -- SQL2012
		--RAISERROR @nErr @cErrmsg
		RETURN
	END
	ELSE
	BEGIN
	   SELECT @bSuccess = 1
		WHILE @@TRANCOUNT > @nStartTCnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END

GO