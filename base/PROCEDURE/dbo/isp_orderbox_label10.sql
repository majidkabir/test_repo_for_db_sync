SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_Orderbox_Label10                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: WMS-3022 - Skechers_Order Box Label                         */
/*                                                                      */
/* Called from: r_dw_order_label10                                      */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_Orderbox_Label10] 
    @c_storerKey        NVARCHAR( 20)
   ,@c_containerkey     NVARCHAR( 20)
AS
BEGIN
   SET NOCOUNT ON			-- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF	
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @c_CONTKEY    NVARCHAR( 20),
          @n_ttlcaseid   INT,
          @n_ttlplt      INT


		CREATE TABLE #TMP_ORDBOXLBL10 (
          rowid        int identity(1,1),
          Storerkey    NVARCHAR(20) NULL,
          COMPANY      NVARCHAR(345) NULL,
          caseid       NVARCHAR(20) NULL,
          PLTKey       NVARCHAR(30) NULL,
          CONTKEY      NVARCHAR(20) NULL,
          ExtOrdKey    NVARCHAR(20) NULL,
          WGT          FLOAT NULL ,
          TTLCASEID    INT NULL,
          TTLPLT       INT NULL)
          
          
          INSERT INTO #TMP_ORDBOXLBL10 (Storerkey,COMPANY,caseid,pltkey,contkey,extordkey,WGT,TTLCaseID,TTLPLT)
          SELECT ORDERS.Storerkey,
                 ISNULL(STO.COMPANY, '') AS COMPANY, 
					  ISNULL(PLTDET.caseid, '') AS  caseid, 
					  ISNULL(CONTAINERDETAIL.Palletkey, '') AS  PLTKey, 
					  ISNULL(CONTAINERDETAIL.ContainerKey, '') AS  CONTKEy, 
					  ISNULL(ORDERS.ExternOrderkey, '') AS  ExtOrdKey, 
					  isnull(md.weight,0) AS WGT,0,0
			FROM ORDERS WITH (NOLOCK)  
			JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey=ORDERS.shipperkey 
			JOIN PALLETDETAIL PLTDET WITH (NOLOCK) ON PLTDET.caseid=ORDERS.userdefine04
			JOIN CONTAINERDETAIL WITH (NOLOCK) ON (PLTDET.palletkey = CONTAINERDETAIL.PALLETKEY)
			LEFT JOIN MBOL M WITH (NOLOCK) ON M.ExternMbolKey = CONTAINERDETAIL.ContainerKey
			LEFT JOIN MBOLDETAIL MD WITH (NOLOCK) ON md.MbolKey=m.MbolKey
			WHERE ORDERS.Storerkey = @c_storerKey
			AND CONTAINERDETAIL.ContainerKey = @c_containerkey
			GROUP BY ORDERS.Storerkey,	ISNULL(STO.COMPANY, '') , 
					   ISNULL(PLTDET.caseid, '') , 
				   	ISNULL(CONTAINERDETAIL.Palletkey, '') , 
				   	ISNULL(CONTAINERDETAIL.ContainerKey, '') , 
					   ISNULL(ORDERS.ExternOrderkey, '') , 
					   ISNULL(md.weight,0) 
          	
    

   DECLARE CUR_loop CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT contkey 
   FROM #TMP_ORDBOXLBL10
   WHERE storerkey = @c_storerKey
   AND CONTKEY = @c_containerkey 
   
   OPEN CUR_loop
   FETCH NEXT FROM CUR_loop INTO @c_contkey
   WHILE @@FETCH_STATUS <> '-1'
   BEGIN
   	
   	SET @n_ttlcaseid = 0
   	SET @n_ttlplt = 0
   	
      SELECT @n_ttlcaseid = COUNT(DISTINCT caseid)
            ,@n_ttlplt = COUNT(DISTINCT pltkey)
      FROM #TMP_ORDBOXLBL10 
      WHERE contkey=@c_CONTKEY
      
   UPDATE #TMP_ORDBOXLBL10
   SET
   	TTLCASEID = @n_ttlcaseid,
   	TTLPLT = @n_ttlplt
    WHERE storerkey = @c_storerKey
   AND CONTKEY = @c_contkey 	

      FETCH NEXT FROM CUR_loop INTO @c_contkey
   END
   CLOSE CUR_loop
   DEALLOCATE CUR_loop

   SELECT Storerkey,COMPANY,caseid,pltkey,contkey,extordkey,WGT,TTLCaseID,TTLPLT
	FROM  #TMP_ORDBOXLBL10 WITH (NOLOCK)   
	WHERE storerkey = @c_storerKey
   AND CONTKEY = @c_containerkey 
   
END

GO