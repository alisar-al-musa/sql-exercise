

-- Joins & filtering
-- 1.	List all orders delivered late (delivered date after the estimated delivery date), including customer city and product category.


-- 1
SELECT C.customer_city, P.product_category_name
FROM core.orders AS O
JOIN core.customers AS C ON C.customer_id = O.customer_id
JOIN core.order_items AS I ON I.order_id = O.order_id
JOIN core.products AS P ON P.product_id = I.product_id

where  order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date < order_delivered_customer_date::date;

-- why date casting: 
-- since estimated date is DATE, and delivered is TIMESTAMP, so estimated-date will be casted to TIMESTAMP as time 00:00 which counts the same day delivery at 1 am as late
-- Now we count the delivered in the same day as estimated as not late regardless of exact time.
-- "Late = arrived on a later calendar day"


-- snapshot of output:
-- 7265 rows

/* 
 cascavel                      | agro_industria_e_comercio
 sao borja                     | cool_stuff
 sorocaba                      | esporte_lazer
 sao jose dos campos           | utilidades_domesticas
 sao goncalo                   | moveis_escritorio
 jequie                        | ferramentas_jardim
 sao luis                      | moveis_escritorio
 itaquirai                     | construcao_ferramentas_iluminacao
 salvador                      | telefonia
 tiangua                       | moveis_cozinha_area_de_servico_jantar_e_jardim
 niteroi                       | casa_conforto
 vila velha                    | malas_acessorios
 pocos de caldas               | utilidades_domesticas
 sao paulo                     | cama_mesa_banho
 monte mor                     | moveis_decoracao
 fortaleza                     | perfumaria
 itapui                        | brinquedos
 rio de janeiro                | 
 braganca paulista             | esporte_lazer
 aracaju                       | utilidades_domesticas
 sao paulo                     | esporte_lazer
 campinas                      | utilidades_domesticas
 marica                        | ferramentas_jardim
 salgueiro                     | beleza_saude
 porto seguro                  | brinquedos
 rio de janeiro                | relogios_presentes
 florianopolis                 | informatica_acessorios
 monte siao                    | cama_mesa_banho
 campo grande                  | brinquedos
 sao paulo                     | esporte_lazer
 barueri                       | moveis_decoracao
 salvador                      | telefonia
 rondonopolis                  | esporte_lazer
 itapolis                      | sinalizacao_e_seguranca
 concordia                     | alimentos
 serra do ramalho              | eletroportateis
 rio de janeiro                | beleza_saude
 buritirama                    | cool_stuff
 sao paulo                     | automotivo
 joao pessoa                   | ferramentas_jardim
 joao pessoa                   | ferramentas_jardim
 diadema                       | brinquedos
 diadema                       | brinquedos
 diadema                       | brinquedos
 aracati                       | utilidades_domesticas
 duque de caxias               | utilidades_domesticas
 rio de janeiro                | automotivo
 santos                        | esporte_lazer
 sao luis                      | moveis_decoracao
 sao luis                      | moveis_decoracao
 maceio                        | audio
 belo horizonte                | beleza_saude
 rio de janeiro                | eletronicos
 londrina                      | telefonia
 salvador                      | eletronicos
 sorocaba                      | beleza_saude
 fortaleza                     | eletronicos
 sao paulo                     | esporte_lazer
 cachoeiro de itapemirim       | 
 sao paulo                     | moveis_escritorio
 niteroi                       | utilidades_domesticas
 belo horizonte                | papelaria
 piracicaba                    | moveis_quarto
 rio de janeiro                | tablets_impressao_imagem
 lauro muller                  | cama_mesa_banho
 petropolis                    | utilidades_domesticas
 niteroi                       | bebes
 paulinia                      | informatica_acessorios
 rio de janeiro                | telefonia
 rio de janeiro                | moveis_decoracao
 rio de janeiro                | moveis_decoracao
 natal                         | relogios_presentes
 franca                        | 
 macaubas                      | papelaria
 teresina                      | beleza_saude
 santos                        | eletrodomesticos
 itapira                       | perfumaria
 betim                         | bebes
 niteroi                       | informatica_acessorios
 seropedica                    | informatica_acessorios
 sao paulo                     | moveis_decoracao
 sao paulo                     | casa_construcao
 belem                         | bebes
 tupancireta                   | beleza_saude
 tupancireta                   | beleza_saude
 tupancireta                   | beleza_saude
 vermelho novo                 | telefonia
 salvador                      | relogios_presentes
 votorantim                    | informatica_acessorios
 breu branco                   | beleza_saude
 rio de janeiro                | cool_stuff
 curaca                        | informatica_acessorios
 cascavel                      | perfumaria
 rio de janeiro                | bebes
 rio de janeiro                | bebes
 conselheiro lafaiete          | cama_mesa_banho
 sao luis                      | eletronicos
 sao paulo                     | beleza_saude
 armacao dos buzios            | cool_stuff
 vitoria                       | telefonia
 vitoria                       | telefonia
 vitoria                       | telefonia
 vitoria                       | telefonia
 vitoria                       | telefonia
*/
