SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetHandoverRptLululemon_RDT                         */
/* Creation Date: 19-DEC-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: mingle01                                                 */
/*                                                                      */
/* Purpose: WMS-11498 - create new Handover Report                      */
/*        :                                                             */
/* Called By: r_dw_handover_rpt_lululemon_rdt                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 19/12/2019  mingle01 1.0   Create new store procedure                */
/* 22/08/2022  mingle01 1.1   WMS-20531 add new column(ML01)            */
/************************************************************************/
CREATE PROC [dbo].[isp_GetHandoverRptLululemon_RDT]
         @c_storerkey      NVARCHAR(15),
         @c_sourcekey      NVARCHAR(50),
         @c_Type           NVARCHAR(10) = ''
             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_mbolkey        NVARCHAR(10) = '',
           @c_extmbolkey     NVARCHAR(50) = ''

   DECLARE @n_NoOfLine       INT    
          ,@c_getstorerkey   NVARCHAR(10)    
          ,@c_getLoadkey     NVARCHAR(20)    
          ,@c_getOrderkey    NVARCHAR(20)    
          ,@c_getExtOrderkey NVARCHAR(20)  
          
   DECLARE @b_Success        INT
         , @n_Err            INT
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_UserId         NVARCHAR(30)
         , @n_cnt            INT
         , @c_Getprinter     NVARCHAR(10) 
         , @c_GetDatawindow  NVARCHAR(50) = 'r_dw_handover_rpt_lululemon_rdt'
         , @c_ReportID       NVARCHAR(10) = 'LULUSHIP'
         , @n_MaxRowID       INT


   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''
   SET @c_UserId    = SUSER_SNAME() 
	
   
   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #Handover_RPT(
      rowid           INT NOT NULL identity(1,1),
      Shipperkey      NVARCHAR(15) NULL,
      Mbolkey         NVARCHAR(10) NULL,
      Externmbolkey   NVARCHAR(30) NULL,
      Externorderkey  NVARCHAR(50) NULL,
      Orderkey        NVARCHAR(10) NULL,
      UserDefine04    NVARCHAR(20) NULL,
		Susr1				 NVARCHAR(20) NULL,	--ML01
		Recgrp          INT	--ML01
   )

   SELECT @c_Getprinter = defaultprinter  
   FROM RDT.RDTUser AS r WITH (NOLOCK)  
   WHERE r.UserName = @c_UserId  

   --SET @c_Getprinter = 'Chooi02'

   IF @c_Type = NULL SET @c_Type = '' 
   
   IF EXISTS (SELECT 1 FROM MBOL (NOLOCK) WHERE MBOLKEY = @c_sourcekey)
      SET @c_mbolkey = @c_sourcekey 
   ELSE 
      SET @c_extmbolkey = @c_sourcekey

   IF @c_type = ''
   BEGIN
      BEGIN TRAN                            
      EXEC isp_PrintToRDTSpooler   
           @c_ReportType     = @c_ReportID,   --UCCLbConso 10 CHARS
           @c_Storerkey      = @c_Storerkey,  --18491'
           @b_success        = @b_success OUTPUT,  
           @n_err            = @n_err     OUTPUT,  
           @c_errmsg         = @c_errmsg  OUTPUT,  
           @n_Noofparam      = 2,  --2
           @c_Param01        = @c_storerkey,  
           @c_Param02        = @c_sourcekey,  
           @c_Param03        = 'H1',  
           @c_Param04        = '',  
           @c_Param05        = '',  
           @c_Param06        = '',  
           @c_Param07        = '',  
           @c_Param08        = '',  
           @c_Param09        = '',  
           @c_Param10        = '',  
           @n_Noofcopy       = 1,  
           @c_UserName       = @c_UserId,    --suser_sname()
           @c_Facility       = '',  
           @c_PrinterID      = @c_Getprinter,  --Printer from RDT.RDTUser
           @c_Datawindow     = @c_GetDatawindow,  --Datawindow name
           @c_IsPaperPrinter = 'Y'
   
      IF @b_success <> 1
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT_SP
      END  
   
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  

      SELECT NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             'Printing Completed'
      GOTO QUIT_SP
   END  

	SET @n_NoOfLine = 50

   BEGIN
      INSERT INTO #Handover_RPT
      SELECT OH.Shipperkey,
             OH.Mbolkey,
             Mbol.Externmbolkey,
             OH.Externorderkey,
             OH.Orderkey,
             OH.Userdefine04,
				 STORER.SUSR1,	--ML01
				 (Row_Number() OVER (PARTITION BY oh.mbolkey ORDER BY oh.mbolkey,oh.OrderKey asc)-1)/@n_NoOfLine	--ML01
      FROM ORDERS OH (NOLOCK)    
      JOIN MBOL (NOLOCK) ON ( OH.Mbolkey = Mbol.Mbolkey )   
		JOIN STORER (NOLOCK) ON STORER.StorerKey = OH.StorerKey
      WHERE OH.storerkey = @c_storerkey 
        AND OH.Mbolkey = CASE WHEN @c_mbolkey <> '' THEN @c_mbolkey ELSE OH.Mbolkey END 
        AND Externmbolkey = CASE WHEN @c_extmbolkey <> '' THEN @c_extmbolkey ELSE Externmbolkey END                  
      GROUP BY OH.Shipperkey,
               OH.Mbolkey,
               Mbol.Externmbolkey,
               OH.Externorderkey,
               OH.Orderkey,
               OH.Userdefine04,
					STORER.SUSR1	--ML01

      SELECT @n_MaxRowID = MAX(ROWID)
      FROM #Handover_RPT

      SELECT Shipperkey    
           , Mbolkey       
           , Externmbolkey 
           , Externorderkey
           , Orderkey      
           , UserDefine04  
           , @n_MaxRowID AS TotalRow
			  , Susr1	--ML01
			  , Recgrp	--ML01
      FROM #Handover_RPT

   END
QUIT_SP:
END -- procedure

GO