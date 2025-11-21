SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : isp_ReScanOutPickSlip                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: ReScan Out PickSlip# when Trigger failed to update          */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Back End Schedule Job                                     */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver    Purposes                               */
/************************************************************************/

CREATE PROC [dbo].[isp_ReScanOutPickSlip] 
AS
BEGIN 
   DECLARE @cPickSlipNo   NVARCHAR(10), 
           @dScanOutDate  datetime 

   DECLARE CUR_PickSlipNo CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT PICKINGINFO.PickSlipNo, PICKINGINFO.ScanOutDate  
      FROM  PICKINGINFO WITH (NOLOCK)
      JOIN  PICKHEADER WITH (NOLOCK) ON PickHeaderKey = PICKINGINFO.PickSlipNo 
      JOIN  PICKDETAIL WITH (NOLOCK) ON PICKHEADER.OrderKey = PICKDETAIL.OrderKey 
                                    AND PickDetail.Status < '5' 
      WHERE PICKINGINFO.ScanOutDate IS NOT NULL 
      AND   PICKHEADER.OrderKey IS NOT NULL 
      AND   PICKHEADER.OrderKey <> '' 
      AND   DateDiff(minute, PICKINGINFO.ScanOutDate, GetDate()) > 10 
      UNION  
      SELECT DISTINCT PICKINGINFO.PickSlipNo, PICKINGINFO.ScanOutDate  
      FROM  PICKINGINFO WITH (NOLOCK)
      JOIN  PICKHEADER WITH (NOLOCK) ON PickHeaderKey = PICKINGINFO.PickSlipNo 
      JOIN  LOADPLANDETAIL WITH (NOLOCK) ON  PICKHEADER.ExternOrderKey = LOADPLANDETAIL.Loadkey
      JOIN  PICKDETAIL WITH (NOLOCK) ON  LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey 
                                    AND PickDetail.Status < '5' 
      WHERE PICKINGINFO.ScanOutDate IS NOT NULL 
      AND   ( PICKHEADER.OrderKey IS NULL OR PICKHEADER.OrderKey = '' )
      AND   DateDiff(minute, PICKINGINFO.ScanOutDate, GetDate()) > 10 
      UNION  
      SELECT DISTINCT PICKINGINFO.PickSlipNo, PICKINGINFO.ScanOutDate 
      FROM  PICKINGINFO WITH (NOLOCK)
      JOIN  PACKHEADER WITH (NOLOCK) ON PACKHEADER.PickSlipNo = PICKINGINFO.PickSlipNo 
                                     AND PACKHEADER.Status = '9' 
      WHERE PICKINGINFO.ScanOutDate IS NULL 
      AND   DateDiff(minute, PACKHEADER.EditDate, GetDate()) > 10 

   OPEN CUR_PickSlipNo 

   FETCH NEXT FROM CUR_PickSlipNo INTO @cPickSlipNo, @dScanOutDate
   WHILE @@FETCH_STATUS <> -1 
   BEGIN 
      BEGIN TRAN 

      INSERT INTO ERRLOG (LogDate, UserId, ErrorID, SystemState, Module, ErrorText)
      VALUES (GetDate(), 'BackEnd', 70001, @cPickSlipNo, 'Pack Confirm', 'Rescan Pickslip #' + @cPickSlipNo)

      IF @dScanOutDate IS NULL 
         SET @dScanOutDate = GETDATE()

      UPDATE PickingInfo WITH (ROWLOCK) 
         SET ScanOutDate = @dScanOutDate 
      WHERE PickSlipNo = @cPickSlipNo 
      IF @@ERROR <> 0 
      BEGIN
         ROLLBACK TRAN 
         BREAK 
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN 
      END 

      FETCH NEXT FROM CUR_PickSlipNo INTO @cPickSlipNo, @dScanOutDate
   END 
   CLOSE CUR_PickSlipNo 
   DEALLOCATE CUR_PickSlipNo
END -- Procedure





GO