SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_RCM_WV_BuildContainer                          */  
/* Creation Date: 13-Jul-2017                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-1880 SG MHAP Build container from Wave                  */  
/*                                                                      */  
/* Called By: Wave Dymaic RCM configure at listname 'RCMConfig'         */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_RCM_WV_BuildContainer]  
   @c_Wavekey NVARCHAR(10),     
   @b_success  int OUTPUT,  
   @n_err      int OUTPUT,  
   @c_errmsg   NVARCHAR(225) OUTPUT,  
   @c_code     NVARCHAR(30)=''  
AS  
BEGIN   
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_continue        INT,  
           @n_cnt             INT,  
           @n_starttcnt       INT  
                              
   DECLARE @c_ID              NVARCHAR(18),
           @c_Sku             NVARCHAR(20),
           @n_NoofPalletByQty DECIMAL(12,2),
           @n_MaxPltPerContr  DECIMAL(12,2),
           @n_MaxWgtPerContr  DECIMAL(12,2),
           @n_PalletWeight    DECIMAL(12,2),
           @n_ContainerCnt    INT,
           @n_ContainerID     INT,
           @n_AddPallet       INT,
           @c_ContainerSize   NVARCHAR(10),
           @c_ContainerKey    NVARCHAR(10),
           @c_LineNo          NVARCHAR(5),
           @n_LineNo          INT,
           @c_Loadkey         NVARCHAR(10),
           @c_Facility        NVARCHAR(5),
           @c_Consigneekey    NVARCHAR(15),
           @n_LoadCount       INT,
           @c_Orderkey        NVARCHAR(10),         
           @c_ExternOrderkey  NVARCHAR(30),
           @c_Door            NVARCHAR(10),
           @c_Type            NVARCHAR(10),
           @c_Route           NVARCHAR(10),
           @c_OrderStatus     NVARCHAR(10),
           @c_DeliveryPlace   NVARCHAR(30),
           @c_CustomerName    NVARCHAR(45),
           @n_TotalCube       FLOAT,
           @n_TotalGrossWgt   FLOAT,
           @d_OrderDate       DATETIME,
           @d_DeliveryDate    DATETIME
                                             
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0       

   --validation
   IF @n_continue IN(1,2)
   BEGIN
      IF EXISTS(SELECT 1 
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                WHERE ISNULL(PD.Id,'') = ''
                AND WD.Wavekey = @c_Wavekey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found empty pallet id in the wave. Unable to build container. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC           
      END
      
      IF EXISTS(SELECT 1 
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey                
                WHERE WD.Wavekey = @c_Wavekey
                AND ISNULL(O.Loadkey,'') <> ''
                HAVING COUNT(DISTINCT O.Loadkey) > 1)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found more than one load plan in the wave. Unable to build container. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC           
      END

      /*IF EXISTS(SELECT 1 
                FROM WAVEDETAIL WD (NOLOCK)
                JOIN PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
                WHERE WD.Wavekey = @c_Wavekey 
                GROUP BY PD.Id
                HAVING COUNT(DISTINCT PD.Sku) > 1)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found multi sku per pallet in the wave. Not allow to build container. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO ENDPROC           
      END*/                
   END      
                              
   --Preparation. create table/retrieve configurations                                
   IF @n_continue IN(1,2)
   BEGIN
      --Create temp table
      CREATE TABLE #TMP_CONTAINER (ContainerId INT NULL,
                                   ContainerSize NVARCHAR(10) NULL,
                                   MaxPltPerContr DECIMAL(12,2) NULL,
                                   MaxWgtPerContr DECIMAL(12,2) NULL,
                                   TotalPalletByID DECIMAL(12,2) NULL,
                                   TotalPalletByQty DECIMAL(12,2) NULL,
                                   TotalWeight DECIMAL(12,2) NULL,
                                   Consigneekey NVARCHAR(15) NULL
                                   )                                                             
      
      --Retrieve consignee container requirement
      SELECT O.Consigneekey,
             CASE WHEN S.Susr1 = 'SLNHY' OR S.Susr2 = 'SLNHY' OR S.Susr3 = 'SLNHY' OR S.Susr4 = 'SLNHY' OR S.Susr5 = 'SLNHY' THEN 'Y' ELSE 'N' END AS B1,
             CASE WHEN S.Susr1 = 'CRET1' OR S.Susr2 = 'CRET1' OR S.Susr3 = 'CRET1' OR S.Susr4 = 'CRET1' OR S.Susr5 = 'CRET1' THEN 'Y' ELSE 'N' END AS B2,  
             CASE WHEN S.Susr1 = 'CCCTR3' OR S.Susr2 = 'CCCTR3' OR S.Susr3 = 'CCCTR3' OR S.Susr4 = 'CCCTR3' OR S.Susr5 = 'CCCTR3' THEN 'Y' ELSE 'N' END AS B3,  
             CASE WHEN S.Susr1 = 'CCTR1' OR S.Susr2 = 'CCTR1' OR S.Susr3 = 'CCTR1' OR S.Susr4 = 'CCTR1' OR S.Susr5 = 'CCTR1' THEN 'Y' ELSE 'N' END AS B4,
             CASE WHEN S.Susr1 = 'CCTR2' OR S.Susr2 = 'CCTR2' OR S.Susr3 = 'CCTR2' OR S.Susr4 = 'CCTR2' OR S.Susr5 = 'CCTR2' THEN 'Y' ELSE 'N' END AS B5  
      INTO #TMP_CONSCOND
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.OrderKey
      JOIN STORER S (NOLOCK) ON O.ConsigneeKey = S.StorerKey  
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY O.Consigneekey,                                                                                                                                    
               CASE WHEN S.Susr1 = 'SLNHY' OR S.Susr2 = 'SLNHY' OR S.Susr3 = 'SLNHY' OR S.Susr4 = 'SLNHY' OR S.Susr5 = 'SLNHY' THEN 'Y' ELSE 'N' END,       
               CASE WHEN S.Susr1 = 'CRET1' OR S.Susr2 = 'CRET1' OR S.Susr3 = 'CRET1' OR S.Susr4 = 'CRET1' OR S.Susr5 = 'CRET1' THEN 'Y' ELSE 'N' END,       
               CASE WHEN S.Susr1 = 'CCCTR3' OR S.Susr2 = 'CCCTR3' OR S.Susr3 = 'CCCTR3' OR S.Susr4 = 'CCCTR3' OR S.Susr5 = 'CCCTR3' THEN 'Y' ELSE 'N' END,  
               CASE WHEN S.Susr1 = 'CCTR1' OR S.Susr2 = 'CCTR1' OR S.Susr3 = 'CCTR1' OR S.Susr4 = 'CCTR1' OR S.Susr5 = 'CCTR1' THEN 'Y' ELSE 'N' END,       
               CASE WHEN S.Susr1 = 'CCTR2' OR S.Susr2 = 'CCTR2' OR S.Susr3 = 'CCTR2' OR S.Susr4 = 'CCTR2' OR S.Susr5 = 'CCTR2' THEN 'Y' ELSE 'N' END        
      
      --retrieve the pallet information and container requirement
      SELECT PD.ID, 
             CASE WHEN C.B3 = 'Y' THEN 10
                      WHEN C.B2 = 'Y' THEN 20 
                      WHEN C.B1 = 'Y' AND SKU.SkuGroup = 'HY' AND SKU.ItemClass = '001' THEN 24
                      ELSE 22 END                
                  AS MaxPltPerContr,
             CASE WHEN C.B5 = 'Y' THEN (22 * 1000)
                      WHEN C.B4 = 'Y' THEN (25 * 1000) 
                      ELSE 999999 END --kg                  
                  AS MaxWgtPerContr,
             CONVERT(DECIMAL(12,2), CASE WHEN PACK.Pallet > 0 THEN SUM(PD.Qty) / PACK.Pallet ELSE 1 END) AS NoofPalletByQty,
             CONVERT(DECIMAL(12,2), SUM(PD.Qty) * SKU.StdGrossWgt) AS PalletWeight,                
             PD.Sku,    
             0 AS ContainerId,   
             SKU.SkuGroup,
             SKU.ItemClass,
             O.Consigneekey --expect one wave one consigneekey
      INTO #TMP_PALLET       
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.OrderKey
      LEFT JOIN #TMP_CONSCOND C (NOLOCK) ON O.ConsigneeKey = C.Consigneekey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey    
      WHERE WD.Wavekey = @c_Wavekey  
      GROUP BY PD.ID, PD.Sku, PACK.Pallet, SKU.StdGrossWgt, SKU.SkuGroup, SKU.ItemClass, O.Consigneekey, 
               C.B1, C.B2, C.B3, C.B4, C.B5           
   END   
   
   --Build container
   IF @n_continue IN(1,2)
   BEGIN  
      DECLARE CUR_PALLET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ID, 
                Sku,
                NoofPalletByQty,
                PalletWeight,
                MaxPltPerContr,
                MaxWgtPerContr,
                Consigneekey                          
         FROM #TMP_PALLET
         ORDER BY MaxPltPerContr, MaxWgtPerContr, NoofPalletByQty DESC, SkuGroup, 
                  CASE WHEN ItemClass = '001' THEN 1 ELSE 2 END, SKU
                  
      OPEN CUR_PALLET   
        
      FETCH NEXT FROM CUR_PALLET INTO @c_ID, @c_Sku, @n_NoofPalletByQty, @n_PalletWeight, @n_MaxPltPerContr, @n_MaxWgtPerContr, @c_Consigneekey
       
      SET @n_ContainerCnt = 0 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
      	  SET @n_ContainerId = 0
      	  SET @n_AddPallet = 1
      	  
      	  --Find container can combine partial pallet 
      	  IF @n_NoofPalletByQty < 1  --loose pallet
      	  BEGIN
      	     SELECT TOP 1 @n_ContainerID = TC.ContainerId 
      	     FROM #TMP_CONTAINER TC
      	     JOIN #TMP_PALLET TP ON TC.ContainerID = TP.ContainerID
      	     WHERE TC.MaxPltPerContr <= @n_MaxPltPerContr  --find container can meet pallet limit
      	     AND TC.MaxWgtPerContr <= @n_MaxWgtperContr --find container can meet weight limit
      	     AND TC.MaxPltPerContr >= TC.TotalPalletByQty + @n_NoofPalletByQty  --check whether can combine partial pallet
      	     AND TC.MaxWgtPerContr >= TC.TotalWeight + @n_PalletWeight --not exceed weight limit
      	     AND (TC.Consigneekey = @c_Consigneekey OR ISNULL(TC.Consigneekey,'') = '' OR ISNULL(@c_Consigneekey,'') = '') --find container with same consignee
      	     --AND TP.Sku = @c_Sku --find pallet with same sku      	     
      	     AND TP.NoofPalletByQty + @n_NoofPalletByQty <= 1   --can combine pallet
      	     ORDER BY CASE WHEN TP.Sku = @c_Sku THEN 1 ELSE 2 END, TC.MaxPltPerContr, TC.MaxWgtPerContr 
      	     
      	     SET @n_AddPallet = 0 --combine pallet not to increate the pallet count of the container
      	  END
      	 
      	  --Find container can fit new pallet
      	  IF ISNULL(@n_ContainerId,0) = 0
      	  BEGIN
      	     SELECT TOP 1 @n_ContainerID = TC.ContainerId 
      	     FROM #TMP_CONTAINER TC
      	     WHERE TC.MaxPltPerContr <= @n_MaxPltPerContr
      	     AND TC.MaxWgtPerContr <= @n_MaxWgtperContr
      	     AND TC.MaxPltPerContr >= TC.TotalPalletByID + @n_NoofPalletByQty  --check whether can fit new pallet
      	     AND TC.MaxWgtPerContr >= TC.TotalWeight + @n_PalletWeight
      	     AND (TC.Consigneekey = @c_Consigneekey OR ISNULL(TC.Consigneekey,'') = '' OR ISNULL(@c_Consigneekey,'') = '') --find container with same consignee
      	     ORDER BY TC.MaxPltPerContr, TC.MaxWgtPerContr   	     
      	  END
      	  
      	  --Create new container
      	  IF ISNULL(@n_ContainerId,0) = 0
      	  BEGIN
      	  	 SET @n_ContainerCnt = @n_ContainerCnt + 1
      	  	 SET @n_ContainerId = @n_ContainerCnt
      	  	   	  	 
      	  	 INSERT INTO #TMP_CONTAINER (ContainerId, ContainerSize, MaxPltPerContr, MaxWgtPerContr, TotalPalletByID, TotalPalletByQty, TotalWeight, Consigneekey)
      	  	                     VALUES (@n_ContainerID, '', @n_MaxPltPerContr, @n_MaxWgtPerContr, 1, @n_NoofPalletByQty, @n_PalletWeight, @c_Consigneekey)
      	  	                     
      	  END   	     	  
      	  ELSE
      	  BEGIN
      	  	 UPDATE #TMP_CONTAINER 
      	  	 SET TotalPalletByID = TotalPalletByID + @n_AddPallet,
      	  	     TotalPalletByQty = TotalPalletByQty + @n_NoofPalletByQty,
      	  	     TotalWeight = TotalWeight + @n_PalletWeight
      	  	 WHERE ContainerId = @n_ContainerId       	  	        	  	      
      	  END
      
	     	UPDATE #TMP_PALLET 
      	  SET ContainerID = @n_ContainerId
      	  WHERE ID = @c_ID                          
      	    
         FETCH NEXT FROM CUR_PALLET INTO @c_ID, @c_Sku, @n_NoofPalletByQty, @n_PalletWeight, @n_MaxPltPerContr, @n_MaxWgtPerContr, @c_Consigneekey
      END
      CLOSE CUR_PALLET
      DEALLOCATE CUR_PALLET
                        
      --Assign container size (20/40 footer)
      UPDATE #TMP_CONTAINER
      SET ContainerSize = CASE WHEN TotalPalletByID <= 10 THEN '20FT' ELSE '40FT' END
   END  

   --create load plan  
   IF @n_continue IN(1,2)
   BEGIN   	  
   	  SELECT @c_Loadkey = MAX(O.Loadkey),
   	         @n_Loadcount = COUNT(DISTINCT ISNULL(O.Loadkey,'')),
   	         @c_Facility = MAX(O.Facility)
   	  FROM WAVEDETAIL WD (NOLOCK) 
   	  JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
   	  WHERE WD.Wavekey = @c_Wavekey   	 
   	     	    	  
   	  IF ISNULL(@c_Loadkey,'') = '' 
   	  BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
            'LOADKEY',
            10,
            @c_loadkey  OUTPUT,
            @b_success     OUTPUT,
            @n_err         OUTPUT,
            @c_errmsg      OUTPUT
         
         IF @b_success <> 1
         BEGIN
           SELECT @n_continue = 3
         END           
         ELSE
         BEGIN
         	  --Create load plan
            INSERT INTO LOADPLAN (Loadkey, Facility)
            VALUES (@c_Loadkey, @c_Facility)
            
  	   	    SELECT @n_err = @@ERROR
   	   	    IF @n_err <> 0
   	        BEGIN
   		        SELECT @n_continue = 3
			        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 35130
			        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert LoadPlan Table. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		        END
         END
      END            	                                      	  
   END
   
   --create loadplandetail
   IF @n_continue IN(1,2) AND @n_LoadCount <= 2 -- 1=all orders empty loadkey 2=some orders empty loadkey
   BEGIN		        	 
	    DECLARE CUR_LOAD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT O.Orderkey, O.ExternOrderkey, O.Door, O.Consigneekey, 
                O.Type, O.Status, O.DeliveryPlace, ISNULL(S.Company,''),
                O.OrderDate, O.DeliveryDate, O.Route,    	 	  	        
       	       SUM(Sku.StdCube * (OD.QtyAllocated + OD.QtyPicked)) AS TotalCube,
                SUM(Sku.StdGrossWgt * (OD.QtyAllocated + OD.QtyPicked)) AS TotalGrossWgt 
         FROM WAVEDETAIL WD (NOLOCK) 
         JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
         JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
         JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
         LEFT JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey
         WHERE WD.Wavekey = @c_Wavekey
         AND ISNULL(O.loadkey,'') = ''
         GROUP BY O.Orderkey, O.ExternOrderkey, O.Door, O.Consigneekey, 
                  O.[Type], O.[Status], O.DeliveryPlace, ISNULL(S.Company,''),
                  O.ExternOrderkey, O.[Route], O.OrderDate, O.DeliveryDate   	 	  	        
      
      OPEN CUR_LOAD   
        
      FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey, @c_ExternOrderkey, @c_Door, @c_Consigneekey, @c_Type, @c_OrderStatus, @c_DeliveryPlace, @c_CustomerName,
                                    @d_Orderdate, @d_DeliveryDate, @c_Route, @n_TotalCube, @n_TotalGrossWgt
       
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN               	       	 	  	          	 	  	                                                     
         EXEC isp_InsertLoadplanDetail
              @c_LoadKey,
              @c_Facility,
              @c_OrderKey,
              @c_ConsigneeKey,
              '9', --@cPrioriry
              @d_OrderDate ,
              @d_DeliveryDate,
              @c_Type,
              @c_Door,
              @c_Route,
              @c_DeliveryPlace,
              @n_TotalGrossWgt,
              @n_TotalCube,
              @c_ExternOrderKey,
              @c_CustomerName,
              0, --@nTotOrderLines
              0, --@nNoOfCartons   
              @c_OrderStatus,
              @b_Success  OUTPUT,
              @n_Err OUTPUT,
              @c_ErrMsg OUTPUT
         
         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert LOADPLANDETAIL Error. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         END    
         
         FETCH NEXT FROM CUR_LOAD INTO @c_Orderkey, @c_ExternOrderkey, @c_Door, @c_Consigneekey, @c_Type, @c_OrderStatus, @c_DeliveryPlace, @c_CustomerName,
                                       @d_Orderdate, @d_DeliveryDate, @c_Route, @n_TotalCube, @n_TotalGrossWgt
      END                                          		        	   
   END
  
   --create container manifest
   IF @n_continue IN(1,2)
   BEGIN   
      DECLARE CUR_CONTRMANIFEST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT ContainerId,
                ContainerSize,
                MaxPltPerContr,
                MaxWgtPerContr,
                Consigneekey                
         FROM #TMP_CONTAINER
         ORDER BY ContainerId
      
      OPEN CUR_CONTRMANIFEST   
        
      FETCH NEXT FROM CUR_CONTRMANIFEST INTO @n_ContainerId, @c_ContainerSize, @n_MaxPltPerContr, @n_MaxWgtPerContr, @c_Consigneekey
      
      --Retieve container 
      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)  
      BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
            'CONTAINERKEY',
            10,
            @c_ContainerKey  OUTPUT,
            @b_success       OUTPUT,
            @n_err           OUTPUT,
            @c_errmsg        OUTPUT

         IF @b_success <> 1
            SELECT @n_continue = 3
         ELSE
         BEGIN
            INSERT INTO CONTAINER (Containerkey, ContainerSize, Loadkey, Userdefine01, Userdefine02, Userdefine03)
            VALUES (@c_ContainerKey, @c_ContainerSize, @c_Loadkey, CAST(CAST(@n_MaxPltPerContr AS INT) AS NVARCHAR), CAST(@n_MaxWgtPerContr AS NVARCHAR), @c_Consigneekey) 
            
  	   	    SELECT @n_err = @@ERROR
   	   	    IF @n_err <> 0
   	        BEGIN
   		        SELECT @n_continue = 3
			        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 35140
			        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Container Table. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		        END               
         END                            
         
         --Retrieve pallets of the container
         DECLARE CUR_PALLETMANIFEST CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT ID,
                   Consigneekey,
                   Sku,
                   NoofPalletByQty,
                   PalletWeight                  
            FROM #TMP_PALLET
            WHERE ContainerId = @n_ContainerId
            ORDER BY NoofPalletByQty DESC, SkuGroup, 
                  CASE WHEN ItemClass = '001' THEN 1 ELSE 2 END, SKU, ID

         OPEN CUR_PALLETMANIFEST   
         
         FETCH NEXT FROM CUR_PALLETMANIFEST INTO @c_ID, @c_Consigneekey, @c_Sku, @n_NoofPalletByQty, @n_PalletWeight
         
         SET @n_LineNo = 0
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN (1,2)  
         BEGIN
         	  IF EXISTS(SELECT 1 FROM CONTAINERDETAIL (NOLOCK) WHERE Containerkey = @c_Containerkey AND Palletkey = @c_Id)
         	  BEGIN
         	  	 --if the pallet have mutiple sku combine into one pallet line
         	     UPDATE CONTAINERDETAIL WITH (ROWLOCK)
         	     SET Userdefine03 = CASE WHEN ISNUMERIC(Userdefine03) = 1 THEN
         	                            CAST(CAST(Userdefine03 AS DECIMAL(12,2)) + @n_NoofPalletByQty AS NVARCHAR)
         	                        ELSE CAST(@n_NoofPalletByQty AS NVARCHAR) END,
         	         Userdefine04 = CASE WHEN ISNUMERIC(Userdefine04) = 1 THEN
         	                            CAST(CAST(Userdefine04 AS DECIMAL(12,2)) + @n_PalletWeight AS NVARCHAR)
         	                        ELSE CAST(@n_PalletWeight AS NVARCHAR) END
               WHERE Containerkey = @c_Containerkey
               AND Palletkey = @c_Id         	     

  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 35150
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update Containerdetail Table. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
			         END                                             	                        
         	  END
         	  ELSE
         	  BEGIN
         	     SELECT @n_LineNo = @n_LineNo + 1
         	     SELECT @c_LineNo = RIGHT('00000' + LTRIM(RTRIM(CAST(@n_LineNo AS NVARCHAR))), 5)
         	     
         	     INSERT INTO CONTAINERDETAIL (Containerkey, ContainerLineNumber, Palletkey, Userdefine01, Userdefine02, Userdefine03, Userdefine04)
         	     VALUES (@c_Containerkey, @c_LineNo, @c_Id, @c_Consigneekey, @c_Sku, CAST(@n_NoofPalletByQty AS NVARCHAR), CAST(@n_PalletWeight AS NVARCHAR))
               
  	   	       SELECT @n_err = @@ERROR
   	   	       IF @n_err <> 0
   	           BEGIN
   		           SELECT @n_continue = 3
			           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 35160
			           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Insert Containerdetail Table. (isp_RCM_WV_BuildContainer)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
		           END  
		        END             
         	  
            FETCH NEXT FROM CUR_PALLETMANIFEST INTO @c_ID, @c_Consigneekey, @c_Sku, @n_NoofPalletByQty, @n_PalletWeight
         END
         CLOSE CUR_PALLETMANIFEST
         DEALLOCATE CUR_PALLETMANIFEST   
            
         FETCH NEXT FROM CUR_CONTRMANIFEST INTO @n_ContainerId, @c_ContainerSize, @n_MaxPltPerContr, @n_MaxWgtPerContr, @c_Consigneekey                                        	                               	
      END
      CLOSE CUR_CONTRMANIFEST
      DEALLOCATE CUR_CONTRMANIFEST
   END
      
     
ENDPROC:   
   
   IF @n_continue=3  -- Error Occured - Process And Return  
  BEGIN  
     SELECT @b_success = 0  
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
     BEGIN  
        ROLLBACK TRAN  
     END  
  ELSE  
     BEGIN  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
     END  
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_BuildContainer'  
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
     RETURN  
  END  
  ELSE  
     BEGIN  
        SELECT @b_success = 1  
        WHILE @@TRANCOUNT > @n_starttcnt  
        BEGIN  
           COMMIT TRAN  
        END  
        RETURN  
     END      
END -- End PROC  

GO