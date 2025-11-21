SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_StartUpGetPendingJob                                */
/* Creation Date: 15-APR-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: AutoRetrieve PendingJob When TCP Socket Spooler start up    */
/*        : If AutoRetrieve=Y at RDTTCPSPL file                         */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_StartUpGetPendingJob]
           @c_HostName           NVARCHAR(40)
         , @c_HostIPAddress      NVARCHAR(40)
         , @c_HostTCPSPLPortNo   NVARCHAR(5)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   SELECT PJ.JobID
   FROM  rdt.RDTPRINTJOB PJ WITH (NOLOCK)
   WHERE PJ.JobId > 0
   AND   PJ.JobType  = 'TCPSPOOLER'
   AND   PJ.JobStatus= '0'
   AND   EXISTS (SELECT 1 FROM RDT.RDTPRINTER PRT WITH (NOLOCK) 
                  JOIN RDT.RDTSPOOLER SPL WITH (NOLOCK) ON PRT.SpoolerGroup = SPL.SpoolerGroup
                  WHERE PRT.Printerid = PJ.Printer
                  AND SPL.IPAddress IN ( @c_HostIPAddress , @c_HostName)
                  AND SPL.PortNo = @c_HostTCPSPLPortNo
                  )

QUIT_SP:

   WHILE @@TRANCOUNT <  @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO