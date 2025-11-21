SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_LoadManifestDet06                              */
/* Creation Date:07-JAN-2021                                            */
/* Copyright: IDS                                                       */
/* Written by:CSCHONG                                                   */
/*                                                                      */
/* Purpose:WMS-15893 PH Ecom Benby Dispatch Manifest (CBOL) CR          */
/*                                                                      */
/* Called By: r_dw_dmanifest_detail_06                                  */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_LoadManifestDet06] (@c_mbolkey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_cbolkey         INT,
           @n_ttlbycbol       INT

   SET @n_cbolkey = 0
   SET @n_ttlbycbol = 1

   CREATE TABLE #TEMP_LoadManidestDET06 (
                                           Mbolkey            NVARCHAR(20) NULL,
                                           CBOLKEY            INT NULL,
                                           CBOLReference      NVARCHAR(30) NULL,
                                           Descr              NVARCHAR(60) NULL,
                                           UserDefine01       NVARCHAR(20) NULL,   
                                           VehicleContainer   NVARCHAR(30) NULL,
                                           SealNo             NVARCHAR(10) NULL,
                                           ProNumber          NVARCHAR(30) NULL,
                                           ExternMBOLKey      NVARCHAR(30) NULL,
                                           ExternOrderkey     NVARCHAR(50) NULL,
                                           MBDUDF01           NVARCHAR(20) NULL,
                                           TTLBYCBOL          INT       
                                        )
   INSERT INTO #TEMP_LoadManidestDET06 (
                                        Mbolkey,CBOLKEY,CBOLReference,Descr,UserDefine01,VehicleContainer,
                                        SealNo,ProNumber,ExternMBOLKey,ExternOrderkey,MBDUDF01,TTLBYCBOL  
                                        )

   SELECT   MB.mbolkey,
            CB.CBOLKey,        
            CB.CBOLReference,  
            F.Descr,
            CB.UserDefine01,     
            CB.VehicleContainer,
            CB.SealNo,
            CB.ProNumber,
            MB.ExternMBOLKey,
            MBD.ExternOrderkey,
            MBD.UserDefine01 AS MBDUDF01,
            0 as TTLCBOL
            FROM MBOL MB WITH (NOLOCK)
            JOIN MBOLDETAIL MBD WITH (NOLOCK) ON MBD.Mbolkey = MB.mbolkey
            JOIN CBOL CB WITH (NOLOCK) ON Cb.cbolkey = MB.cbolkey
            JOIN Facility F WITH (NOLOCK) ON F.facility = MB.Facility
            WHERE MB.mbolkey = @c_mbolkey
            order by CB.CBOLKey,MB.ExternMBOLKey


      SELECT TOP 1 @n_cbolkey = cbolkey 
      FROM #TEMP_LoadManidestDET06
      where mbolkey = @c_mbolkey


     SELECT @n_ttlbycbol = COUNT(ExternOrderkey)
     FROM MBOL M WITH (NOLOCK)
     JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.mbolkey = M.mbolkey 
     Where cbolkey = @n_cbolkey


    UPDATE #TEMP_LoadManidestDET06 
    SET TTLBYCBOL = @n_ttlbycbol
    WHERE Cbolkey = @n_cbolkey


    SELECT * FROM #TEMP_LoadManidestDET06
    ORDER BY Cbolkey,Externmbolkey
  

END

GO