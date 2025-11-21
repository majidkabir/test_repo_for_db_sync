SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspDPAssignCartonNo                                */
/* Creation Date:  20-May-2008                                          */
/* Copyright: IDS                                                       */
/* Written by:  James                                                   */
/*                                                                      */
/* Purpose:  Auto assign carton no for loose QTY carton                 */
/*           SOS105503                                                  */
/* Input Parameters:  @c_PickSlipNo  - (PickslipNo)                     */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC Assign carton no                                     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/

CREATE PROC [dbo].[nspDPAssignCartonNo] 
   @c_PickSlipNo   NVARCHAR( 10),
   @b_Success      INT           OUTPUT, 
   @n_err          INT           OUTPUT, 
   @c_errmsg       NVARCHAR( 250) OUTPUT 
AS
BEGIN

   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    


   DECLARE 
      @c_LabelNo           NVARCHAR( 20),
      @c_MinSKU            NVARCHAR( 20),
      @c_MaxSKU            NVARCHAR( 20),
      @n_CartonNo          INT,
      @n_MaxCartonNo       INT,
      @n_continue          INT,
		@n_StartTranCnt      INT,
      @n_LineNo            INT, 
      @nDupLabelLine       INT,
      @cNewLabelLine       NVARCHAR( 5),
      @nCartonNo           INT,
      @cLabelLine          NVARCHAR(5) 
      

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

   -- Available only when packheader not pack confirmed
   IF EXISTS (SELECT 1 FROM PackHeader PH WITH (NOLOCK) 
		JOIN ORDERS O WITH (NOLOCK) ON PH.LoadKey = O.LoadKey
      WHERE PH.PickSlipNo = @c_PickSlipNo
         AND O.Status = '9')
	BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63501
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot assign carton no when pack confirmed. (nspDPAssignCartonNo)'
	END

   -- Available only where there are loose qty to sort
   IF NOT EXISTS (SELECT 1 FROM PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
         AND (Refno = '' OR Refno = NULL))
	BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63501
		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Cannot assign carton no when there are no loose qty to sort. (nspDPAssignCartonNo)'
	END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- Get the Max Carton No
      SELECT @n_MaxCartonNo = MAX(CartonNo)
      FROM PackDetail WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
         AND Refno <> ''

      IF @n_MaxCartonNo = NULL
      BEGIN
         SET @n_MaxCartonNo = 1
      END
      ELSE
      BEGIN
         SET @n_MaxCartonNo = @n_MaxCartonNo + 1
      END

      DECLARE cur_cartonsort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT MIN(SKU), MAX(SKU), LabelNo
      FROM PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
         AND (Refno = '' OR Refno = NULL)
      GROUP BY LabelNo
      ORDER BY MIN(SKU), MAX(SKU)

      OPEN cur_cartonsort
      FETCH NEXT FROM cur_cartonsort INTO @c_MinSKU, @c_MaxSKU, @c_LabelNo
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @nDupLabelLine = 0

         SELECT @nDupLabelLine = COUNT(DISTINCT LabelLine) 
         FROM PackDetail (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
            AND LabelNo = @c_LabelNo
         GROUP BY LabelLine 
         HAVING COUNT(DISTINCT LabelLine) > 1

--          SELECT *
--          FROM PackDetail (NOLOCK)
--          WHERE PickSlipNo = @c_PickSlipNo
--             AND LabelNo = @c_LabelNo

         IF @nDupLabelLine > 1 
         BEGIN
            SET @cNewLabelLine = '00000'

            DECLARE CurUpdatePackDet CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT CartonNo, LabelLine
            FROM  PackDetail (NOLOCK)
            WHERE PickSlipNo = @c_PickSlipNo
            AND LabelNo = @c_LabelNo
            ORDER BY CartonNo, LabelLine 

            OPEN CurUpdatePackDet

            FETCH NEXT FROM CurUpdatePackDet INTO @nCartonNo, @cLabelLine
            
            WHILE @@FETCH_STATUS <> -1
            BEGIN

               SET @cNewLabelLine = RIGHT('0000' + dbo.fnc_RTRIM(CONVERT(char(5), CAST(@cNewLabelLine as int) + 1)),5)


               UPDATE PACKDETAIL
                  SET CartonNo = @n_MaxCartonNo,
                      LabelLine = @cNewLabelLine, 
                      ArchiveCop = NULL
               WHERE PickSlipNo = @c_PickSlipNo
               AND   LabelNo = @c_LabelNo
               AND   LabelLine = @cLabelLine
               AND   CartonNo  = @nCartonNo

               SELECT @n_err = @@ERROR
      
               IF @n_err <> 0 
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63501
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Carton No on PackDetail failed. (nspDPAssignCartonNo)'
                  GOTO RETURN_SP
               END

               FETCH NEXT FROM CurUpdatePackDet INTO @nCartonNo, @cLabelLine
            END

            CLOSE CurUpdatePackDet
            DEALLOCATE CurUpdatePackDet

         END
         ELSE
         BEGIN

            UPDATE PackDetail SET
               CartonNo = @n_MaxCartonNo,
               ArchiveCop = NULL
            WHERE PickSlipNo = @c_PickSlipNo
               AND LabelNo = @c_LabelNo

            SELECT @n_err = @@ERROR
   
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63501
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Carton No on PackDetail failed. (nspDPAssignCartonNo)'
               GOTO RETURN_SP
            END
         END  


         SET @n_MaxCartonNo = @n_MaxCartonNo + 1

         FETCH NEXT FROM cur_cartonsort INTO @c_MinSKU, @c_MaxSKU, @c_LabelNo
      END
      CLOSE cur_cartonsort
      DEALLOCATE cur_cartonsort
   END
END
RETURN_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
	SELECT @b_success = 0
	IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
	BEGIN
		ROLLBACK TRAN
	END
	ELSE
	BEGIN
		WHILE @@TRANCOUNT > @n_StartTranCnt
		BEGIN
			COMMIT TRAN
		END
	END
	execute nsp_logerror @n_err, @c_errmsg, 'nspDPAssignCartonNo'
	RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	RETURN
END
ELSE
BEGIN
	SELECT @b_success = 1
	WHILE @@TRANCOUNT > @n_StartTranCnt
	BEGIN
		COMMIT TRAN
	END
	RETURN
END

GO